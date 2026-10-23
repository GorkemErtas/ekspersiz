package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.exception.InsufficientAnalysisCreditException;
import com.gorkem.vehicle_inspector.service.billing.CreditCatalog;
import com.gorkem.vehicle_inspector.service.billing.BillingSandboxPolicy;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.sql.Timestamp;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.*;

/** Short database transactions only; no network or inference work while holding wallet locks. */
@Service
public class CreditWalletService {
    private final JdbcTemplate jdbc;
    private final Clock clock;
    private final BillingSandboxPolicy sandboxPolicy;
    public CreditWalletService(JdbcTemplate jdbc, Clock clock) { this(jdbc, clock, new BillingSandboxPolicy("")); }
    @Autowired
    public CreditWalletService(JdbcTemplate jdbc, Clock clock, BillingSandboxPolicy sandboxPolicy) {
        this.jdbc=jdbc; this.clock=clock; this.sandboxPolicy=sandboxPolicy;
    }
    public record Balance(long permanent, long periodic, long available, long debt, LocalDateTime periodEndsAt) {}
    public record Account(String id, boolean business, boolean canPurchase, boolean owner, Map<String,Balance> balances,
                          long usedSlots, long totalSlots) {}
    public record Overview(Account personal, Account company, List<CreditCatalog.Product> products) {}
    public record Reservation(UUID token, boolean completed) {}
    private LocalDateTime now() { return LocalDateTime.now(clock); }
    private static LocalDateTime date(Object value) { return value == null ? null : ((Timestamp)value).toLocalDateTime(); }
    private static long number(Map<String,Object> row, String key) { return ((Number)row.get(key)).longValue(); }

    private String personal(User user) { return "user:" + user.getId(); }

    @Transactional
    public Overview overview(User user) {
        Account personal = account(user, false);
        Account company = membership(user).isEmpty() ? null : account(user, true);
        return new Overview(personal, company, CreditCatalog.products());
    }

    public List<Map<String,Object>> membership(User user) {
        return jdbc.queryForList("SELECT business_account_id,role FROM business_members WHERE user_id=?", user.getId());
    }

    private String resolve(User user, boolean business, boolean purchase) {
        return resolve(user,business,purchase,true);
    }

    private String resolve(User user, boolean business, boolean purchase, boolean requireActive) {
        if (!business) return personal(user);
        var members = membership(user);
        if (members.isEmpty()) throw new IllegalStateException("Şirket üyeliği bulunamadı.");
        var member=members.getFirst();
        if (purchase && !"OWNER".equals(member.get("role")))
            throw new IllegalStateException("Şirket adına yalnızca şirket sahibi satın alabilir.");
        long id=number(member,"business_account_id");
        var owners=jdbc.queryForList("SELECT u.subscription_plan,u.subscription_expires_at FROM users u JOIN business_members m ON m.user_id=u.id WHERE m.business_account_id=? AND m.role='OWNER'",id);
        if (requireActive && (owners.isEmpty() || !"BUSINESS".equals(owners.getFirst().get("subscription_plan"))
                || date(owners.getFirst().get("subscription_expires_at")) == null
                || !date(owners.getFirst().get("subscription_expires_at")).isAfter(now())))
            throw new IllegalStateException("Şirket aboneliği aktif değil.");
        return "business:"+id;
    }

    private void lock(String account) {
        jdbc.execute("SET LOCAL lock_timeout='3s'");
        boolean company=account.startsWith("business:");
        long id=Long.parseLong(account.substring(account.indexOf(':')+1));
        jdbc.update("INSERT INTO credit_accounts(id,user_id,business_id) VALUES (?,?,?) ON CONFLICT DO NOTHING",
                account,company?null:id,company?id:null);
        jdbc.queryForObject("SELECT id FROM credit_accounts WHERE id=? FOR UPDATE",String.class,account);
        for (String resource:List.of("ANALYSIS","ASSISTANT","SLOT"))
            jdbc.update("INSERT INTO credit_wallets(account_id,resource) VALUES (?,?) ON CONFLICT DO NOTHING",account,resource);
        refreshPeriod(account,company,id);
        for (var reservation:jdbc.queryForList("SELECT * FROM credit_reservations WHERE account_id=? AND state='RESERVED' AND expires_at<=?",account,now()))
            releaseLocked(reservation);
    }

    private void refreshPeriod(String account, boolean company, long id) {
        String sql=company
                ? "SELECT u.* FROM users u JOIN business_members m ON m.user_id=u.id WHERE m.business_account_id=? AND m.role='OWNER'"
                : "SELECT * FROM users WHERE id=?";
        var users=jdbc.queryForList(sql,id);
        if (users.isEmpty()) return;
        var owner=users.getFirst();
        var start=date(owner.get("subscription_started_at"));
        var end=date(owner.get("subscription_expires_at"));
        String plan=String.valueOf(owner.get("subscription_plan"));
        boolean eligible=company ? plan.equals("BUSINESS") : Set.of("PLUS","PRO").contains(plan);
        if (!eligible || start==null || end==null || !end.isAfter(now())) {
            jdbc.update("UPDATE credit_wallets SET periodic=0 WHERE account_id=?",account);
            return;
        }
        for (String resource:List.of("ANALYSIS","ASSISTANT")) {
            int amount=company ? (resource.equals("ANALYSIS")?100:200)
                    : resource.equals("ANALYSIS") ? (plan.equals("PRO")?10:5)
                    : (plan.equals("PRO")?5:3)*Math.max(1,(int)java.time.temporal.ChronoUnit.DAYS.between(start,end));
            String key="period:"+account+":"+resource+":"+start.format(java.time.format.DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss.SSSSSS"));
            int inserted=jdbc.update("INSERT INTO credit_events(event_key,account_id,resource,amount,reason) VALUES (?,?,?,?, 'SUBSCRIPTION') ON CONFLICT DO NOTHING",key,account,resource,amount);
            if (inserted>0) jdbc.update("UPDATE credit_wallets SET periodic=?,period_start=?,period_end=? WHERE account_id=? AND resource=? AND (period_start IS NULL OR period_start<=?)",amount,start,end,account,resource,start);
            // A grace extension changes expiry, never grants a second allocation.
            jdbc.update("UPDATE credit_wallets SET period_end=? WHERE account_id=? AND resource=? AND period_start=?",end,account,resource,start);
        }
    }

    @Transactional
    public Account account(User user, boolean business) {
        String id=resolve(user,business,false,false);
        lock(id);
        Map<String,Balance> balances=new LinkedHashMap<>();
        for (var row:jdbc.queryForList("SELECT * FROM credit_wallets WHERE account_id=?",id)) {
            long p=number(row,"permanent"),period=number(row,"periodic"),debt=number(row,"debt");
            balances.put((String)row.get("resource"),new Balance(p,period,Math.max(0,p+period-debt),debt,date(row.get("period_end"))));
        }
        long base=business?10:1;
        if (!business) {
            // Preserve the paid legacy vehicle allowance until its paid period ends.
            var rows=jdbc.queryForList("SELECT subscription_plan,subscription_expires_at FROM users WHERE id=?",user.getId());
            var row=rows.getFirst(); var end=date(row.get("subscription_expires_at"));
            if (end!=null && end.isAfter(now())) base=switch(String.valueOf(row.get("subscription_plan"))) { case "PLUS" -> 3; case "PRO" -> 10; default -> 1; };
        }
        long used=jdbc.queryForObject("SELECT COUNT(*) FROM vehicles WHERE NOT archived AND " +(business?"business_account_id":"user_id")+"=?",Long.class,Long.parseLong(id.split(":")[1]));
        boolean owner=!business || "OWNER".equals(membership(user).getFirst().get("role"));
        boolean canPurchase=owner;
        if (business) {
            try { resolve(user,true,false); } catch (IllegalStateException inactive) { canPurchase=false; }
        }
        return new Account(id,business,canPurchase,owner,Map.copyOf(balances),used,base+balances.get("SLOT").available());
    }

    @Transactional
    public void validateSlots(User user, boolean business) {
        var account=account(user,business);
        if (account.usedSlots()>=account.totalSlots()) throw new IllegalStateException(
                "Araç kapasitesi dolu ("+account.usedSlots()+"/"+account.totalSlots()+"). Krediler ve Paketler ekranından araç slotu satın alın.");
    }

    @Transactional
    public void validateBusinessSlots(long businessId) {
        String account="business:"+businessId; lock(account);
        Boolean active=jdbc.queryForObject("SELECT EXISTS(SELECT 1 FROM business_members m JOIN users u ON u.id=m.user_id WHERE m.business_account_id=? AND m.role='OWNER' AND u.subscription_plan='BUSINESS' AND u.subscription_expires_at>?)",Boolean.class,businessId,now());
        if (!Boolean.TRUE.equals(active)) throw new IllegalStateException("Yeni şirket aracı eklemek için Business aboneliğinizi yenileyin.");
        long extras=jdbc.queryForObject("SELECT GREATEST(0,permanent-debt) FROM credit_wallets WHERE account_id=? AND resource='SLOT'",Long.class,account);
        long used=jdbc.queryForObject("SELECT COUNT(*) FROM vehicles WHERE business_account_id=? AND NOT archived",Long.class,businessId);
        if (used>=10+extras) throw new IllegalStateException("Şirket araç kapasitesi dolu ("+used+"/"+(10+extras)+"). Şirket sahibi ek araç slotu satın alabilir.");
    }

    @Transactional
    public Reservation reserve(User user, boolean business, String resource, String operationKey, String requestHash) {
        jdbc.execute("SET LOCAL lock_timeout='3s'");
        jdbc.queryForObject("SELECT pg_advisory_xact_lock(hashtextextended(?, 0))",Object.class,"credit-user:"+user.getId());
        if (!Set.of("ANALYSIS","ASSISTANT").contains(resource) || operationKey==null || operationKey.length()>160)
            throw new IllegalArgumentException("Geçersiz kredi işlemi.");
        String account=resolve(user,business,false);
        lock(account);
        // Serialize duplicate requests, including a retry after an expired lease.
        var existing=jdbc.queryForList("SELECT * FROM credit_reservations WHERE account_id=? AND resource=? AND operation_key=? AND state<>'RELEASED'",account,resource,operationKey);
        if (!existing.isEmpty()) {
            var r=existing.getFirst();
            if (number(r,"user_id")!=user.getId() || !requestHash.equals(r.get("request_hash")))
                throw new IllegalStateException("İstek anahtarı farklı bir işlemde kullanıldı.");
            if ("COMPLETED".equals(r.get("state"))) return new Reservation((UUID)r.get("token"),true);
            if ("RESERVED".equals(r.get("state"))) throw new IllegalStateException("İşleminiz devam ediyor. Lütfen bekleyin.");
        }
        Long active=jdbc.queryForObject("SELECT COUNT(*) FROM credit_reservations WHERE user_id=? AND state='RESERVED' AND expires_at>?",Long.class,user.getId(),now());
        if (active!=null && active>0) throw new IllegalStateException("Devam eden işleminiz tamamlandıktan sonra tekrar deneyin.");
        var wallet=jdbc.queryForMap("SELECT * FROM credit_wallets WHERE account_id=? AND resource=?",account,resource);
        if (number(wallet,"permanent")+number(wallet,"periodic")-number(wallet,"debt")<1)
            throw new InsufficientAnalysisCreditException(resource.equals("ANALYSIS")
                    ? "Hasar analiz krediniz yetersiz. Krediler ve Paketler ekranından kredi alın."
                    : "AI Asistan krediniz yetersiz. Krediler ve Paketler ekranından kredi alın.");
        int periodic=number(wallet,"periodic")>0?1:0,permanent=1-periodic;
        UUID token=UUID.randomUUID();
        jdbc.update("UPDATE credit_wallets SET permanent=permanent-?,periodic=periodic-? WHERE account_id=? AND resource=?",permanent,periodic,account,resource);
        jdbc.update("INSERT INTO credit_reservations(token,account_id,user_id,resource,operation_key,request_hash,permanent,periodic,period_start,state,expires_at) VALUES (?,?,?,?,?,?,?,?,?,'RESERVED',?)",
                token,account,user.getId(),resource,operationKey,requestHash,permanent,periodic,wallet.get("period_start"),now().plusMinutes(10));
        return new Reservation(token,false);
    }

    private Map<String,Object> owned(User user, UUID token) {
        var rows=jdbc.queryForList("SELECT * FROM credit_reservations WHERE token=? AND user_id=?",token,user.getId());
        if (rows.isEmpty()) throw new IllegalStateException("Kredi rezervasyonu bulunamadı.");
        lock((String)rows.getFirst().get("account_id"));
        return jdbc.queryForMap("SELECT * FROM credit_reservations WHERE token=?",token);
    }

    @Transactional
    public void complete(User user, UUID token) {
        var r=owned(user,token);
        if ("COMPLETED".equals(r.get("state"))) return;
        if (!"RESERVED".equals(r.get("state")) || !date(r.get("expires_at")).isAfter(now()))
            throw new IllegalStateException("İşlem zaman aşımına uğradı; kredi iade edildi. Tekrar deneyin.");
        jdbc.update("UPDATE credit_reservations SET state='COMPLETED' WHERE token=?",token);
        jdbc.update("INSERT INTO credit_events(event_key,account_id,resource,amount,reason) VALUES (?,?,?,-1,'CONSUMPTION') ON CONFLICT DO NOTHING",
                "consume:"+token,r.get("account_id"),r.get("resource"));
    }

    @Transactional
    public void assertReservation(User user,UUID token) {
        var r=owned(user,token);
        if (!"RESERVED".equals(r.get("state")) || !date(r.get("expires_at")).isAfter(now()))
            throw new IllegalStateException("Kredi rezervasyonunun süresi doldu. Lütfen tekrar deneyin.");
    }

    @Transactional
    public void completeWithResponse(User user,UUID token,String response) {
        complete(user,token);
        jdbc.update("UPDATE credit_reservations SET response_json=? WHERE token=? AND user_id=?",response,token,user.getId());
    }

    @Transactional(readOnly=true)
    public String response(User user,UUID token) {
        return jdbc.queryForObject("SELECT response_json FROM credit_reservations WHERE token=? AND user_id=? AND state='COMPLETED'",String.class,token,user.getId());
    }

    @Transactional
    public void release(User user, UUID token) {
        if (Boolean.TRUE.equals(jdbc.queryForObject("SELECT EXISTS(SELECT 1 FROM credit_reservations WHERE token=? AND user_id=?)",Boolean.class,token,user.getId())))
            releaseLocked(owned(user,token));
    }

    @Transactional(readOnly=true)
    public boolean reservationActive(User user,UUID token) {
        return Boolean.TRUE.equals(jdbc.queryForObject("SELECT EXISTS(SELECT 1 FROM credit_reservations WHERE token=? AND user_id=? AND state='RESERVED' AND expires_at>?)",Boolean.class,token,user.getId(),now()));
    }

    private void releaseLocked(Map<String,Object> r) {
        if (!"RESERVED".equals(r.get("state"))) return;
        jdbc.update("UPDATE credit_wallets SET permanent=permanent+?,periodic=periodic+CASE WHEN period_start=? AND period_end>? THEN ? ELSE 0 END WHERE account_id=? AND resource=?",
                r.get("permanent"),r.get("period_start"),now(),r.get("periodic"),r.get("account_id"),r.get("resource"));
        jdbc.update("UPDATE credit_reservations SET state='RELEASED' WHERE token=?",r.get("token"));
    }

    @Transactional
    public UUID preparePurchase(User user, String productId) {
        var product=CreditCatalog.find(productId);
        if (product==null) throw new IllegalArgumentException("Ürün bulunamadı.");
        String account=resolve(user,product.business(),true);
        lock(account);
        UUID id=UUID.randomUUID();
        jdbc.update("INSERT INTO credit_purchase_intents(id,customer_id,product_id,account_id,created_at,expires_at) VALUES (?,?,?,?,?,?)",id,user.ensureBillingCustomerId(),productId,account,now(),now().plusDays(30));
        return id;
    }

    @Transactional
    public void purchase(User user, String productId, String transactionId, LocalDateTime purchasedAt, boolean refund) {
        purchase(user, productId, transactionId, purchasedAt, refund, false);
    }

    /** Environment comes exclusively from authenticated RevenueCat webhook/API data. */
    @Transactional
    public void purchase(User user, String productId, String transactionId, LocalDateTime purchasedAt, boolean refund, boolean sandbox) {
        if (sandbox && !refund && !sandboxPolicy.allowsPurchase(user, productId)) return;
        String environment = sandbox ? "SANDBOX" : "PRODUCTION";
        jdbc.execute("SET LOCAL lock_timeout='3s'");
        var product=CreditCatalog.find(productId);
        int legacy=switch(productId==null?"":productId) { case "analysis_1" -> 1; case "analysis_3" -> 3; case "analysis_10" -> 10; default -> 0; };
        if (product==null && legacy==0) return;
        if (transactionId==null || transactionId.isBlank()) throw new IllegalArgumentException("Satın alma işlem kimliği eksik.");
        // PostgreSQL transaction lock makes global transaction ownership independent of the current account.
        jdbc.queryForObject("SELECT pg_advisory_xact_lock(hashtextextended(?, 0))",Object.class,"purchase:"+transactionId);
        // Keep the raw-ID lock across environments to serialize legacy collision checks too.
        var legacyRows=jdbc.queryForList("SELECT * FROM credit_purchases WHERE transaction_id=? AND environment='LEGACY'",transactionId);
        if (sandbox && !legacyRows.isEmpty()) return;
        var existing=legacyRows.isEmpty()
                ? jdbc.queryForList("SELECT * FROM credit_purchases WHERE transaction_id=? AND environment=?",transactionId,environment)
                : legacyRows;
        if (!existing.isEmpty()) {
            var old=existing.getFirst();
            if (!refund || Boolean.TRUE.equals(old.get("refunded"))) return;
            if (!productId.equals(old.get("product_id"))) throw new IllegalStateException("Satın alma ürünü uyuşmuyor.");
            String account=(String)old.get("account_id");
            if (account!=null) {
                lock(account);
                String resource=(String)old.get("resource"); long amount=number(old,"quantity");
                // Refund debt cannot produce spendable negative balances or be evaded by consuming first.
                jdbc.update("UPDATE credit_wallets SET debt=debt+GREATEST(0,?-permanent),permanent=GREATEST(0,permanent-?) WHERE account_id=? AND resource=?",amount,amount,account,resource);
                event("refund:"+old.get("environment")+":"+transactionId,account,resource,-amount,"REFUND");
            }
            jdbc.update("UPDATE credit_purchases SET refunded=TRUE WHERE transaction_id=? AND environment=?",transactionId,old.get("environment"));
            return;
        }
        if (refund) {
            jdbc.update("INSERT INTO credit_purchases(transaction_id,product_id,refunded,environment) VALUES (?,?,TRUE,?)",transactionId,productId,environment);
            return;
        }
        String account=personal(user);
        if (product!=null) {
            if (purchasedAt==null) throw new IllegalStateException("Satın alım tarihi eksik.");
            var intents=jdbc.queryForList("SELECT account_id FROM credit_purchase_intents WHERE customer_id=? AND product_id=? AND created_at<=? AND expires_at>=? ORDER BY created_at DESC LIMIT 1",user.ensureBillingCustomerId(),productId,purchasedAt,purchasedAt);
            // Unattributed purchases stay unconfirmed; a foreign restore must not block
            // synchronizing subsequent purchases or subscription status for this customer.
            if (intents.isEmpty()) return;
            account=(String)intents.getFirst().get("account_id");
        }
        lock(account);
        String resource=product==null?"ANALYSIS":product.resource(); int amount=product==null?legacy:product.quantity();
        jdbc.update("INSERT INTO credit_purchases(transaction_id,customer_id,account_id,product_id,resource,quantity,environment) VALUES (?,?,?,?,?,?,?)",transactionId,user.ensureBillingCustomerId(),account,productId,resource,amount,environment);
        jdbc.update("UPDATE credit_wallets SET permanent=permanent+? WHERE account_id=? AND resource=?",amount,account,resource);
        event("purchase:"+environment+":"+transactionId,account,resource,amount,"PURCHASE");
    }

    private void event(String key,String account,String resource,long amount,String reason) {
        jdbc.update("INSERT INTO credit_events(event_key,account_id,resource,amount,reason) VALUES (?,?,?,?,?) ON CONFLICT DO NOTHING",key,account,resource,amount,reason);
    }

    @Transactional(readOnly=true)
    public boolean purchaseConfirmed(User user,String transaction) {
        return Boolean.TRUE.equals(jdbc.queryForObject("SELECT EXISTS(SELECT 1 FROM credit_purchases WHERE transaction_id=? AND customer_id=? AND NOT refunded AND account_id IS NOT NULL AND (environment<>'SANDBOX' OR ?))",Boolean.class,transaction,user.ensureBillingCustomerId(),sandboxPolicy.allows(user)));
    }

    @Transactional
    public void grantWelcome(User user, String deviceHash, String identityHash) {
        String account=personal(user); lock(account);
        int claimed=jdbc.update("INSERT INTO credit_welcome_claims(device_hash,identity_hash,account_id) VALUES (?,?,?) ON CONFLICT DO NOTHING",deviceHash,identityHash,account);
        if (claimed==0) return;
        for (String resource:List.of("ANALYSIS","ASSISTANT")) {
            int amount=resource.equals("ANALYSIS")?1:2;
            jdbc.update("UPDATE credit_wallets SET permanent=permanent+? WHERE account_id=? AND resource=?",amount,account,resource);
            event("welcome:"+account+":"+resource,account,resource,amount,"WELCOME");
        }
    }
}
