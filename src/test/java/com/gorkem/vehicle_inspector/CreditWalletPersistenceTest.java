package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.service.CreditWalletService;
import com.gorkem.vehicle_inspector.service.billing.CreditCatalog;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.condition.EnabledIfSystemProperty;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.transaction.support.TransactionTemplate;
import java.nio.file.*;
import java.time.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.function.Supplier;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/** Opt-in, isolated PostgreSQL schema; never runs against the application database. */
@EnabledIfSystemProperty(named="credit.test.jdbc-url",matches="jdbc:postgresql://[^/]+/credit_system_test")
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
class CreditWalletPersistenceTest {
    JdbcTemplate jdbc; TransactionTemplate tx; CreditWalletService service;
    User user,other; MutableClock clock=new MutableClock();
    static class MutableClock extends Clock {
        Instant instant=Instant.parse("2026-10-19T10:00:00Z");
        public ZoneId getZone(){return ZoneOffset.UTC;} public Clock withZone(ZoneId z){return this;} public Instant instant(){return instant;}
    }
    <T> T inTx(Supplier<T> action) {return tx.execute(status -> action.get());}
    void run(Runnable action) {tx.executeWithoutResult(status -> action.run());}
    LocalDateTime now(){return LocalDateTime.now(clock);}
    @BeforeAll void schema() throws Exception {
        String url=System.getProperty("credit.test.jdbc-url");
        var ds=new DriverManagerDataSource(url,System.getProperty("credit.test.username","credit_test"),"");
        var admin=new JdbcTemplate(ds);
        admin.execute("CREATE SCHEMA IF NOT EXISTS credit_wallet_test");
        ds=new DriverManagerDataSource(url+"?currentSchema=credit_wallet_test,public",System.getProperty("credit.test.username","credit_test"),"");
        jdbc=new JdbcTemplate(ds);tx=new TransactionTemplate(new DataSourceTransactionManager(ds));
        // V1 is a pg_dump with explicit public names. Rewrite ONLY the isolated test schema.
        for (int n=1;n<=17;n++) {
            final int version=n;
            Path file;
            try(var paths=Files.list(Path.of("src/main/resources/db/migration"))) {
                file=paths.filter(p -> p.getFileName().toString().startsWith("V"+version+"__")).findFirst().orElseThrow();
            }
            String sql=Files.readString(file).replace("\uFEFF","").replace("public.","credit_wallet_test.");
            // pgvector is unrelated to credits and is not installed in the local Windows cluster.
            sql=sql.replace("CREATE EXTENSION IF NOT EXISTS vector;","").replace("VECTOR(384)","REAL[]")
                    .replaceAll("(?s)CREATE INDEX idx_ai_knowledge_chunks_embedding.*?;","");
            if (version==14) {
                jdbc.execute("INSERT INTO users(id,full_name,email,password,subscription_plan,email_verified,subscription_started_at,subscription_expires_at) VALUES (8001,'Legacy','legacy@example.com','unused','PLUS',TRUE,CURRENT_TIMESTAMP-INTERVAL '3 days',CURRENT_TIMESTAMP+INTERVAL '27 days')");
                jdbc.execute("INSERT INTO analysis_credit_transactions(user_id,type,amount,product_id,external_transaction_id,created_at) VALUES (8001,'PURCHASE',5,'analysis_10','legacy-transaction',CURRENT_TIMESTAMP)");
                jdbc.execute("INSERT INTO analysis_usages(user_id,started_at) VALUES (8001,CURRENT_TIMESTAMP),(8001,CURRENT_TIMESTAMP)");
                for (int i=0;i<4;i++) jdbc.update("INSERT INTO vehicles(user_id,plate,brand,model,model_year,mileage,archived,primary_vehicle) VALUES (8001,?,'Test','Car',2024,0,FALSE,FALSE)","LEGACY"+i);
            }
            jdbc.execute(sql);
            if (version==14) {
                assertEquals(5L,jdbc.queryForObject("SELECT permanent FROM credit_wallets WHERE account_id='user:8001' AND resource='ANALYSIS'",Long.class));
                assertEquals(3L,jdbc.queryForObject("SELECT periodic FROM credit_wallets WHERE account_id='user:8001' AND resource='ANALYSIS'",Long.class));
                assertEquals(3L,jdbc.queryForObject("SELECT permanent FROM credit_wallets WHERE account_id='user:8001' AND resource='SLOT'",Long.class));
                assertEquals(1,jdbc.queryForObject("SELECT COUNT(*) FROM credit_purchases WHERE transaction_id='legacy-transaction'",Integer.class));
                assertEquals(2,jdbc.queryForObject("SELECT COUNT(*) FROM credit_events WHERE reason='LEGACY_PERIOD'",Integer.class));
            }
            if (version==16) {
                assertEquals(5L,jdbc.queryForObject("SELECT permanent FROM credit_wallets WHERE account_id='user:8001' AND resource='ANALYSIS'",Long.class));
                assertEquals("LEGACY",jdbc.queryForObject("SELECT environment FROM credit_purchases WHERE transaction_id='legacy-transaction'",String.class));
            }
        }
        service=new CreditWalletService(jdbc,clock);
    }
    @BeforeEach void setup() {
        jdbc.execute("TRUNCATE credit_accounts,users,business_accounts CASCADE");
        clock.instant=Instant.parse("2026-10-19T10:00:00Z");
        user=createUser(9001);other=createUser(9002);
        service=new CreditWalletService(jdbc,clock,
                new com.gorkem.vehicle_inspector.service.billing.BillingSandboxPolicy(user.getBillingCustomerId()));
    }
    User createUser(long id) {
        User u=new User("Credit test","credit"+id+"@example.com","unused");
        ReflectionTestUtils.setField(u,"id",id);
        jdbc.update("INSERT INTO users(id,full_name,email,password,subscription_plan,email_verified,billing_customer_id) VALUES (?,?,?,?,'FREE',TRUE,?)",id,"Credit test",u.getEmail(),"unused",u.ensureBillingCustomerId());
        return u;
    }
    void buy(User u,String product,String transaction) {
        if (CreditCatalog.find(product)!=null) run(() -> service.preparePurchase(u,product));
        run(() -> service.purchase(u,product,transaction,now(),false));
    }
    long balance(User u,String resource) {return inTx(() -> service.account(u,false).balances().get(resource).available());}
    CreditWalletService.Reservation reserve(User u,String key) {return inTx(() -> service.reserve(u,false,"ANALYSIS",key,"same"));}
    @Test void catalogHasExactDiscounts() {
        assertEquals("189.95",CreditCatalog.find("eksper_analysis_5").referencePrice().toString());
        assertEquals("639.84",CreditCatalog.find("eksper_analysis_20").referencePrice().toString());
        assertEquals("159.84",CreditCatalog.find("eksper_assistant_20").referencePrice().toString());
        assertEquals("4999.99",CreditCatalog.BUSINESS_PRICE.toString());
    }
    @Test void purchasesAreGloballyIdempotentAndIndependent() {
        buy(user,"eksper_analysis_5","a");buy(user,"eksper_analysis_5","a");
        buy(other,"eksper_analysis_5","a");buy(user,"eksper_assistant_10","b");
        assertEquals(5,balance(user,"ANALYSIS"));assertEquals(10,balance(user,"ASSISTANT"));assertEquals(0,balance(other,"ANALYSIS"));
    }
    @Test void reservationReleaseExpiryAndStaleCompletion() {
        buy(user,"eksper_analysis_1","a");var first=reserve(user,"first");assertEquals(0,balance(user,"ANALYSIS"));
        run(() -> service.release(user,first.token()));assertEquals(1,balance(user,"ANALYSIS"));
        var second=reserve(user,"second");clock.instant=clock.instant.plusSeconds(601);
        assertEquals(1,balance(user,"ANALYSIS"));assertThrows(IllegalStateException.class,() -> run(() -> service.complete(user,second.token())));
        var third=reserve(user,"third");run(() -> service.complete(user,third.token()));run(() -> service.complete(user,third.token()));
        assertTrue(reserve(user,"third").completed());assertEquals(0,balance(user,"ANALYSIS"));
    }
    @Test void refundBeforePurchaseAndRefundDebt() {
        run(() -> service.purchase(user,"eksper_analysis_1","before",now(),true));
        buy(user,"eksper_analysis_1","before");assertEquals(0,balance(user,"ANALYSIS"));
        buy(user,"eksper_analysis_1","spent");var r=reserve(user,"spent");run(() -> service.complete(user,r.token()));
        run(() -> service.purchase(user,"eksper_analysis_1","spent",now(),true));
        buy(user,"eksper_analysis_5","new");assertEquals(4,balance(user,"ANALYSIS"));
    }
    @Test void delayedStorePurchaseIsAttributedWithinThirtyDaysOnly() {
        run(() -> service.preparePurchase(user,"eksper_analysis_5"));
        clock.instant=clock.instant.plus(Duration.ofDays(4));
        run(() -> service.purchase(user,"eksper_analysis_5","pending-four-days",now(),false));
        run(() -> service.purchase(user,"eksper_analysis_5","pending-four-days",now(),false));
        assertTrue(service.purchaseConfirmed(user,"pending-four-days"));
        assertEquals(5,balance(user,"ANALYSIS"));

        run(() -> service.preparePurchase(other,"eksper_assistant_1"));
        clock.instant=clock.instant.plus(Duration.ofDays(31));
        run(() -> service.purchase(other,"eksper_assistant_1","outside-window",now(),false));
        assertFalse(service.purchaseConfirmed(other,"outside-window"));
        assertEquals(0,balance(other,"ASSISTANT"));
    }
    @Test void welcomeCannotBeRepeatedByAccountDeviceOrDeletedEmail() {
        run(() -> service.grantWelcome(user,"device-a","identity-a"));
        run(() -> service.grantWelcome(user,"device-b","identity-a"));
        run(() -> service.grantWelcome(other,"device-a","identity-b"));
        assertEquals(1,balance(user,"ANALYSIS"));assertEquals(2,balance(user,"ASSISTANT"));assertEquals(0,balance(other,"ANALYSIS"));
        jdbc.update("DELETE FROM users WHERE id=?",user.getId());
        run(() -> service.grantWelcome(other,"device-c","identity-a"));assertEquals(0,balance(other,"ANALYSIS"));
    }
    void company() {
        jdbc.update("UPDATE users SET subscription_plan='BUSINESS',subscription_started_at=?,subscription_expires_at=? WHERE id=?",now().minusDays(3),now().plusDays(27),user.getId());
        jdbc.update("INSERT INTO business_accounts(id,company_name,created_at) VALUES (77,'Test',?)",now());
        jdbc.update("INSERT INTO business_members(business_account_id,user_id,role,joined_at) VALUES (77,?,'OWNER',?),(77,?,'MEMBER',?)",user.getId(),now(),other.getId(),now());
    }

    @AfterEach void clearWorkspaceRequest() {
        org.springframework.web.context.request.RequestContextHolder.resetRequestAttributes();
    }

    @Test void membershipAndWorkspaceSwitchingPreserveIndependentCreditPools() {
        buy(other,"eksper_analysis_5","before-joining");
        company();
        WorkspaceResolverTest.request("PERSONAL");
        var personal = inTx(() -> service.overview(other));
        assertEquals(5, personal.personal().balances().get("ANALYSIS").available());
        assertNull(personal.company());
        var own = reserve(other,"own-analysis");
        run(() -> service.complete(other,own.token()));

        WorkspaceResolverTest.request("BUSINESS");
        var shared = inTx(() -> service.overview(other));
        assertNull(shared.personal());
        assertEquals(100,shared.company().balances().get("ANALYSIS").available());
        var company = inTx(() -> service.reserve(other,true,"ANALYSIS","company-analysis","hash"));
        run(() -> service.complete(other,company.token()));
        assertEquals(99,inTx(() -> service.account(other,true).balances().get("ANALYSIS").available()));

        WorkspaceResolverTest.request("PERSONAL");
        assertEquals(4,balance(other,"ANALYSIS"));
        assertThrows(com.gorkem.vehicle_inspector.exception.WorkspaceAccessDeniedException.class,
                () -> run(() -> service.preparePurchase(other,"eksper_analysis_5_business")));
        run(() -> service.preparePurchase(other,"eksper_analysis_1"));
        // Owner's personal account also remains independent of the Business plan.
        assertTrue(inTx(() -> service.account(user,false).canPurchase()));
    }

    @Test void switchingDuringAReservationCannotChargeTheOtherAccountButCanRefundOriginal() {
        buy(other,"eksper_analysis_5","personal"); company();
        WorkspaceResolverTest.request("BUSINESS");
        var reservation = inTx(() -> service.reserve(other,true,"ASSISTANT","question","hash"));
        WorkspaceResolverTest.request("PERSONAL");
        assertThrows(com.gorkem.vehicle_inspector.exception.WorkspaceAccessDeniedException.class,
                () -> run(() -> service.complete(other,reservation.token())));
        run(() -> service.release(other,reservation.token()));
        assertEquals(5,balance(other,"ANALYSIS"));
        assertEquals(200,inTx(() -> service.account(other,true).balances().get("ASSISTANT").available()));
    }

    @Test void removedMemberCannotCompleteOrReplayCompanyWorkButReservationIsRefundable() {
        company();
        WorkspaceResolverTest.request("BUSINESS");
        var reservation = inTx(() -> service.reserve(other,true,"ANALYSIS","before-removal","hash"));
        jdbc.update("DELETE FROM business_members WHERE user_id=?",other.getId());
        assertThrows(com.gorkem.vehicle_inspector.exception.WorkspaceAccessDeniedException.class,
                () -> run(() -> service.complete(other,reservation.token())));
        run(() -> service.release(other,reservation.token()));
        assertEquals(100,inTx(() -> service.account(user,true).balances().get("ANALYSIS").available()));
        WorkspaceResolverTest.request("PERSONAL");
        assertEquals(0,balance(other,"ANALYSIS"));
    }

    @Test void webhookUsesPurchaseIntentAccountAfterClientChangesWorkspace() {
        company();
        WorkspaceResolverTest.request("BUSINESS");
        run(() -> service.preparePurchase(user,"eksper_analysis_5_business"));
        WorkspaceResolverTest.request("PERSONAL");
        run(() -> service.purchase(user,"eksper_analysis_5_business","paid-company",now(),false));
        assertEquals(0,balance(user,"ANALYSIS"));
        assertEquals(105,inTx(() -> service.account(user,true).balances().get("ANALYSIS").available()));
        run(() -> service.purchase(user,"eksper_analysis_5_business","paid-company",now(),true));
        assertEquals(100,inTx(() -> service.account(user,true).balances().get("ANALYSIS").available()));
        assertEquals(0,balance(user,"ANALYSIS"));
    }
    @Test void companyRenewalAndOwnerOnlyPurchases() {
        company();assertEquals(100,inTx(() -> service.account(other,true).balances().get("ANALYSIS").available()));
        assertThrows(IllegalStateException.class,() -> run(() -> service.preparePurchase(other,"eksper_analysis_5_business")));
        run(() -> service.preparePurchase(user,"eksper_analysis_5_business"));buy(user,"eksper_analysis_5_business","company-purchase");
        var r=inTx(() -> service.reserve(other,true,"ANALYSIS","company-use","same"));run(() -> service.complete(other,r.token()));
        assertEquals(104,inTx(() -> service.account(user,true).balances().get("ANALYSIS").available()));
        assertEquals(0,balance(user,"ANALYSIS"));
        jdbc.update("UPDATE users SET subscription_started_at=?,subscription_expires_at=? WHERE id=?",now(),now().plusMonths(1),user.getId());
        assertEquals(105,inTx(() -> service.account(other,true).balances().get("ANALYSIS").available()));
        assertEquals(105,inTx(() -> service.account(other,true).balances().get("ANALYSIS").available()));
    }
    @Test void lastCompanyCreditCannotBeSpentTwice() throws Exception {
        company();run(() -> service.account(user,true));
        jdbc.update("UPDATE credit_wallets SET periodic=1 WHERE account_id='business:77' AND resource='ANALYSIS'");
        var pool=Executors.newFixedThreadPool(2);var gate=new CountDownLatch(1);
        try {
            List<Future<Boolean>> results=new ArrayList<>();
            for (User actor:List.of(user,other)) results.add(pool.submit(() -> {
                gate.await();try {var r=inTx(() -> service.reserve(actor,true,"ANALYSIS","last:"+actor.getId(),"same"));run(() -> service.complete(actor,r.token()));return true;} catch(com.gorkem.vehicle_inspector.exception.InsufficientAnalysisCreditException e){return false;}
            }));
            gate.countDown();int successes=0;for(var result:results) if(result.get(10,TimeUnit.SECONDS))successes++;
            assertEquals(1,successes);assertEquals(0,inTx(() -> service.account(user,true).balances().get("ANALYSIS").available()));
        } finally {pool.shutdownNow();}
    }
    @Test void slotsArePermanentAndCheckedInsideCreationTransaction() {
        buy(user,"eksper_slot_1","slot");assertEquals(2,inTx(() -> service.account(user,false).totalSlots()));
        for(int i=0;i<2;i++){final int index=i;run(() -> {service.validateSlots(user,false);jdbc.update("INSERT INTO vehicles(user_id,plate,brand,model,model_year,mileage,archived,primary_vehicle) VALUES (?,?,'Test','Car',2024,0,FALSE,FALSE)",user.getId(),"TEST"+index);});}
        assertThrows(IllegalStateException.class,() -> run(() -> service.validateSlots(user,false)));
        jdbc.update("UPDATE vehicles SET archived=TRUE WHERE plate='TEST0'");run(() -> service.validateSlots(user,false));
    }
    @AfterAll void cleanup() {if(jdbc!=null)jdbc.execute("DROP SCHEMA credit_wallet_test CASCADE");}

    @Test void simultaneousVehicleCreationCannotExceedLastSlot() throws Exception {
        var pool=Executors.newFixedThreadPool(2);var gate=new CountDownLatch(1);
        try {
            List<Future<Boolean>> results=new ArrayList<>();
            for(int i=0;i<2;i++) {final int index=i;results.add(pool.submit(() -> {
                gate.await();try {run(() -> {service.validateSlots(user,false);
                    jdbc.update("INSERT INTO vehicles(user_id,plate,brand,model,model_year,mileage,archived,primary_vehicle) VALUES (?,?,'Test','Car',2024,0,FALSE,FALSE)",user.getId(),"RACE"+index);
                });return true;}catch(IllegalStateException full){return false;}
            }));}
            gate.countDown();int successes=0;for(var result:results) if(result.get(10,TimeUnit.SECONDS))successes++;
            assertEquals(1,successes);assertEquals(1,inTx(() -> service.account(user,false).usedSlots()));
        } finally {pool.shutdownNow();}
    }

    @Test void deletedUserErasesCachedAnswerButPreservesPurchaseAndWelcomeTombstones() {
        buy(user,"eksper_assistant_1","saved");
        var r=inTx(() -> service.reserve(user,false,"ASSISTANT","question","hash"));
        run(() -> service.completeWithResponse(user,r.token(),"private answer"));
        jdbc.update("DELETE FROM users WHERE id=?",user.getId());
        assertNull(jdbc.queryForObject("SELECT response_json FROM credit_reservations WHERE token=?",String.class,r.token()));
        buy(other,"eksper_assistant_1","saved");assertEquals(0,balance(other,"ASSISTANT"));
    }

    @Test void companyExpiryPreservesPersonalCreditsAndCannotSpendCompanyFunds() {
        company();buy(other,"eksper_analysis_5","personal");run(() -> service.account(other,true));
        jdbc.update("UPDATE users SET subscription_expires_at=? WHERE id=?",now().minusSeconds(1),user.getId());
        assertThrows(IllegalStateException.class,() -> inTx(() -> service.reserve(other,true,"ANALYSIS","expired","hash")));
        assertFalse(inTx(() -> service.account(user,true).canPurchase()));
        assertTrue(inTx(() -> service.account(user,true).owner()));
        jdbc.update("DELETE FROM business_members WHERE user_id=?",other.getId());
        assertEquals(5,balance(other,"ANALYSIS"));
    }

    @Test void unattributedRestoreCannotGrantOrBlockOtherPurchases() {
        run(() -> service.purchase(other,"eksper_analysis_5","unattributed",now(),false));
        assertFalse(service.purchaseConfirmed(other,"unattributed"));
        assertEquals(0,balance(other,"ANALYSIS"));
        buy(other,"eksper_analysis_1","valid");assertEquals(1,balance(other,"ANALYSIS"));
    }

    @Test void sandboxCreditsCanBeSpentAndRefundedExactlyOnceWithoutTouchingProductionCollision() {
        buy(other,"eksper_analysis_5","same-id");
        run(() -> service.preparePurchase(user,"eksper_analysis_5"));
        run(() -> service.purchase(user,"eksper_analysis_5","same-id",now(),false,true));
        run(() -> service.purchase(user,"eksper_analysis_5","same-id",now(),false,true));
        assertEquals(5,balance(user,"ANALYSIS"));
        assertTrue(service.purchaseConfirmed(user,"same-id"));
        var r=reserve(user,"use-sandbox");run(() -> service.complete(user,r.token()));
        assertEquals(4,balance(user,"ANALYSIS"));
        // Revocation must not block a verified refund of an already delivered purchase.
        service=new CreditWalletService(jdbc,clock);
        run(() -> service.purchase(null,"eksper_analysis_5","same-id",now(),true,true));
        run(() -> service.purchase(null,"eksper_analysis_5","same-id",now(),true,true));
        assertEquals(0,balance(user,"ANALYSIS"));
        assertEquals(1,inTx(() -> service.account(user,false).balances().get("ANALYSIS").debt()));
        assertEquals(5,balance(other,"ANALYSIS"));
        assertFalse(service.purchaseConfirmed(user,"same-id"));
        assertTrue(service.purchaseConfirmed(other,"same-id"));
        assertEquals(2,jdbc.queryForObject("SELECT count(*) FROM credit_purchases WHERE transaction_id='same-id'",Integer.class));
        assertEquals(1,jdbc.queryForObject("SELECT count(*) FROM credit_events WHERE event_key='refund:SANDBOX:same-id'",Integer.class));
    }

    @Test void sandboxAuthorizationCannotBeBypassedAtWalletAndCannotFundCompany() {
        company();
        run(() -> service.preparePurchase(other,"eksper_analysis_5"));
        run(() -> service.purchase(other,"eksper_analysis_5","unauthorized",now(),false,true));
        run(() -> service.preparePurchase(user,"eksper_analysis_5_business"));
        run(() -> service.purchase(user,"eksper_analysis_5_business","shared",now(),false,true));
        assertEquals(0,balance(other,"ANALYSIS"));
        assertEquals(100,inTx(() -> service.account(other,true).balances().get("ANALYSIS").available()));
        assertEquals(0,jdbc.queryForObject("SELECT count(*) FROM credit_purchases",Integer.class));
    }

    @Test void sandboxRefundBeforePurchaseCannotPoisonProductionOrBeRegranted() {
        run(() -> service.purchase(null,"eksper_analysis_5","early-refund",now(),true,true));
        buy(user,"eksper_analysis_5","early-refund");
        run(() -> service.purchase(user,"eksper_analysis_5","early-refund",now(),false,true));
        assertEquals(5,balance(user,"ANALYSIS"));
        assertEquals(2,jdbc.queryForObject("SELECT count(*) FROM credit_purchases WHERE transaction_id='early-refund'",Integer.class));
    }

    @Test void historicalUnclassifiedPurchaseIsNeverRegrantedOrRefundedBySandbox() {
        buy(user,"eksper_analysis_5","historical");
        jdbc.update("UPDATE credit_purchases SET environment='LEGACY' WHERE transaction_id='historical'");
        run(() -> service.purchase(user,"eksper_analysis_5","historical",now(),false,true));
        run(() -> service.purchase(user,"eksper_analysis_5","historical",now(),true,true));
        buy(user,"eksper_analysis_5","historical");
        assertEquals(5,balance(user,"ANALYSIS"));
        run(() -> service.purchase(user,"eksper_analysis_5","historical",now(),true,false));
        assertEquals(0,balance(user,"ANALYSIS"));
        assertEquals(1,jdbc.queryForObject("SELECT count(*) FROM credit_purchases WHERE transaction_id='historical'",Integer.class));
    }

    @Test void concurrentSandboxReplayHasOneOwnerAndOneGrant() throws Exception {
        var policy=new com.gorkem.vehicle_inspector.service.billing.BillingSandboxPolicy(user.getBillingCustomerId()+","+other.getBillingCustomerId());
        service=new CreditWalletService(jdbc,clock,policy);
        run(() -> service.preparePurchase(user,"eksper_analysis_5"));
        run(() -> service.preparePurchase(other,"eksper_analysis_5"));
        var pool=Executors.newFixedThreadPool(4);var gate=new CountDownLatch(1);
        try {
            List<Future<?>> results=new ArrayList<>();
            for (User actor:List.of(user,other,user,other)) results.add(pool.submit(() -> {
                gate.await();run(() -> service.purchase(actor,"eksper_analysis_5","race",now(),false,true));return null;
            }));
            gate.countDown();for(var result:results) result.get(10,TimeUnit.SECONDS);
            assertEquals(5,balance(user,"ANALYSIS")+balance(other,"ANALYSIS"));
            assertEquals(1,jdbc.queryForObject("SELECT count(*) FROM credit_purchases WHERE transaction_id='race'",Integer.class));
        } finally {pool.shutdownNow();}
    }

    @Test void authenticatedWebhookAndRevenueCatReconciliationRecoverOldPurchaseWithoutDoubleGrant() {
        var users=mock(com.gorkem.vehicle_inspector.repository.UserRepository.class);
        when(users.findByEmail(user.getEmail())).thenReturn(Optional.of(user));
        when(users.findByBillingCustomerId(user.getBillingCustomerId())).thenReturn(Optional.of(user));
        var subscriptions=mock(com.gorkem.vehicle_inspector.repository.BillingSubscriptionRepository.class);
        var events=mock(com.gorkem.vehicle_inspector.repository.BillingWebhookEventRepository.class);
        when(events.existsByProviderEventIdAndEnvironmentIn(anyString(),any())).thenAnswer(call -> {
            Collection<String> environments=call.getArgument(1);
            return jdbc.queryForObject("SELECT EXISTS(SELECT 1 FROM billing_webhook_events WHERE provider_event_id=? AND environment IN (?,?))",
                    Boolean.class,call.getArgument(0),environments.toArray()[0],environments.toArray()[1]);
        });
        when(events.save(any())).thenAnswer(call -> {
            Object event=call.getArgument(0);
            jdbc.update("INSERT INTO billing_webhook_events(provider_event_id,event_type,app_user_id,processed_at,environment) VALUES (?,?,?,?,?)",
                    ReflectionTestUtils.getField(event,"providerEventId"),ReflectionTestUtils.getField(event,"eventType"),
                    ReflectionTestUtils.getField(event,"appUserId"),now(),ReflectionTestUtils.getField(event,"environment"));
            return event;
        });
        var plans=mock(com.gorkem.vehicle_inspector.service.SubscriptionService.class);
        when(plans.getEffectivePlan(user)).thenReturn(com.gorkem.vehicle_inspector.entity.SubscriptionPlan.FREE);
        var http=mock(org.springframework.web.client.RestTemplate.class);
        var response=new tools.jackson.databind.ObjectMapper().readTree("""
                {"subscriber":{"non_subscriptions":{"eksper_analysis_5":[
                {"id":"internal-rc-id","store_transaction_id":"recovered-order","is_sandbox":true,
                "store":"play_store","purchase_date":"2026-10-19T10:00:00Z"}]}}}
                """);
        when(http.exchange(anyString(),eq(org.springframework.http.HttpMethod.GET),any(org.springframework.http.HttpEntity.class),
                eq(tools.jackson.databind.JsonNode.class),eq(user.getBillingCustomerId())))
                .thenReturn(org.springframework.http.ResponseEntity.ok(response));
        var billing=new com.gorkem.vehicle_inspector.service.BillingService(users,subscriptions,events,plans,
                new com.gorkem.vehicle_inspector.client.RevenueCatClient(http,"https://api.revenuecat.com/v1","server-secret"),
                new com.gorkem.vehicle_inspector.service.billing.RevenueCatWebhookVerifier("webhook-secret","",clock),
                new com.fasterxml.jackson.databind.ObjectMapper(),clock);
        ReflectionTestUtils.setField(billing,"creditWallets",service);
        run(() -> service.preparePurchase(user,"eksper_analysis_5"));
        // Before authorization the provider purchase is real, but no credit is delivered.
        run(() -> billing.sync(user.getEmail()));assertEquals(0,balance(user,"ANALYSIS"));
        ReflectionTestUtils.setField(billing,"sandboxPolicy",
                new com.gorkem.vehicle_inspector.service.billing.BillingSandboxPolicy(user.getBillingCustomerId()));
        // A long-delayed sync uses the verified purchase time, not today's date or a new intent.
        clock.instant=clock.instant.plus(Duration.ofDays(40));
        run(() -> billing.sync(user.getEmail()));
        run(() -> billing.sync(user.getEmail()));
        assertEquals(5,balance(user,"ANALYSIS"));assertTrue(service.purchaseConfirmed(user,"recovered-order"));
        String webhook="""
                {"event":{"id":"recovered-event","environment":"SANDBOX","type":"NON_RENEWING_PURCHASE",
                "app_user_id":"%s","product_id":"eksper_analysis_5","transaction_id":"recovered-order",
                "purchased_at_ms":1792404000000}}
                """.formatted(user.getBillingCustomerId());
        assertThrows(com.gorkem.vehicle_inspector.exception.InvalidBillingWebhookException.class,
                () -> run(() -> billing.processRevenueCatWebhook("forged",null,webhook)));
        run(() -> billing.processRevenueCatWebhook("webhook-secret",null,webhook));
        run(() -> billing.processRevenueCatWebhook("webhook-secret",null,webhook));
        assertEquals(5,balance(user,"ANALYSIS"));
        assertEquals(1,jdbc.queryForObject("SELECT count(*) FROM credit_events WHERE event_key='purchase:SANDBOX:recovered-order'",Integer.class));
        assertEquals("SANDBOX",jdbc.queryForObject("SELECT environment FROM billing_webhook_events WHERE provider_event_id='recovered-event'",String.class));
        // Identical provider IDs in different environments are distinct at the PostgreSQL boundary.
        jdbc.update("INSERT INTO billing_webhook_events(provider_event_id,event_type,processed_at,environment) VALUES ('recovered-event','TEST',?,'PRODUCTION')",now());
    }
}
