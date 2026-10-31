import java.io.*;
import java.nio.*;
import java.nio.file.*;
import java.security.*;
import java.security.cert.X509Certificate;
import java.util.*;
import java.util.jar.*;

/** Reads existing Java signing properties without passwords in argv, logs, or generated source. */
class ReleaseIdentity {
    static class ReleaseFailure extends Exception {
        ReleaseFailure(String reason) { super(reason); }
    }
    static String fingerprint(X509Certificate cert, String algorithm) throws Exception {
        return HexFormat.of().withUpperCase().formatHex(MessageDigest.getInstance(algorithm).digest(cert.getEncoded()));
    }

    static X509Certificate signingCertificate(String propertiesFile, String baseDirectory) throws Exception {
        Properties properties = new Properties();
        try (var input = Files.newInputStream(Path.of(propertiesFile))) { properties.load(input); }
        for (String name : List.of("storeFile", "storePassword", "keyAlias", "keyPassword"))
            if (properties.getProperty(name, "").isBlank()) throw new ReleaseFailure("incomplete signing properties");
        Path store = Path.of(properties.getProperty("storeFile"));
        if (!store.isAbsolute()) store = Path.of(baseDirectory).resolve(store);
        char[] storePassword = properties.getProperty("storePassword").toCharArray();
        char[] keyPassword = properties.getProperty("keyPassword").toCharArray();
        try {
            KeyStore keys = KeyStore.getInstance(store.toFile(), storePassword);
            String alias = properties.getProperty("keyAlias");
            if (!keys.isKeyEntry(alias) || !(keys.getKey(alias, keyPassword) instanceof PrivateKey))
                throw new ReleaseFailure("private upload key unavailable");
            X509Certificate cert = (X509Certificate) keys.getCertificate(alias);
            cert.checkValidity();
            return cert;
        } finally {
            Arrays.fill(storePassword, '\0'); Arrays.fill(keyPassword, '\0'); properties.clear();
        }
    }

    static void checkNativeAlignment(byte[] header) throws Exception {
        if (header.length < 64 || header[0] != 0x7f || header[1] != 'E' || header[2] != 'L' || header[3] != 'F')
            throw new ReleaseFailure("invalid native ELF");
        if (header[4] != 2) return; // Play's 16 KiB requirement concerns 64-bit libraries.
        ByteBuffer elf = ByteBuffer.wrap(header).order(header[5] == 1 ? ByteOrder.LITTLE_ENDIAN : ByteOrder.BIG_ENDIAN);
        long offset = elf.getLong(32);
        int size = Short.toUnsignedInt(elf.getShort(54)), count = Short.toUnsignedInt(elf.getShort(56));
        if (size < 56 || offset < 64 || offset + (long) size * count > header.length)
            throw new ReleaseFailure("invalid ELF program headers");
        for (int index = 0; index < count; index++) {
            int start = Math.toIntExact(offset + (long) index * size);
            if (elf.getInt(start) == 1 && elf.getLong(start + 48) < 16384)
                throw new ReleaseFailure("64-bit native library is not 16 KiB aligned");
        }
    }

    static final List<String> REFLECTIVE_CLASSES = List.of(
        "androidx.work.impl.WorkDatabase_Impl",
        "androidx.work.OverwritingInputMerger",
        "androidx.work.ArrayCreatingInputMerger");

    /** Inspect defined direct methods, not string-pool references or R8 mapping text. */
    static class Dex {
        final ByteBuffer data;
        Dex(byte[] bytes) throws ReleaseFailure {
            if (bytes.length < 112 || !new String(bytes, 0, 8, java.nio.charset.StandardCharsets.US_ASCII)
                    .matches("dex\\n0(35|37|38|39|40)\\x00") || bytes[40] != 0x78)
                throw new ReleaseFailure("unsupported or truncated DEX header");
            data = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN);
            if (get(32) != bytes.length || get(36) != 112)
                throw new ReleaseFailure("invalid DEX size/header");
        }
        int get(int offset) { return data.getInt(offset); }
        int ushort(int offset) { return Short.toUnsignedInt(data.getShort(offset)); }
        int uleb(int[] cursor) throws ReleaseFailure {
            int value = 0;
            for (int shift = 0; shift <= 28; shift += 7) {
                int next = Byte.toUnsignedInt(data.get(cursor[0]++));
                if (shift == 28 && (next & 0xf0) != 0) throw new ReleaseFailure("invalid DEX ULEB128");
                value |= (next & 127) << shift;
                if ((next & 128) == 0) return value;
            }
            throw new ReleaseFailure("invalid DEX ULEB128");
        }
        String string(int index) throws ReleaseFailure {
            if (index < 0 || index >= get(56)) throw new ReleaseFailure("invalid DEX string index");
            int[] cursor = { get(get(60) + 4 * index) };
            uleb(cursor);
            int start = cursor[0], end = start;
            while (data.get(end) != 0) end++;
            return new String(data.array(), start, end - start, java.nio.charset.StandardCharsets.UTF_8);
        }
        String type(int index) throws ReleaseFailure {
            if (index < 0 || index >= get(64)) throw new ReleaseFailure("invalid DEX type index");
            return string(get(get(68) + 4 * index));
        }
        void constructors(Set<String> found) throws ReleaseFailure {
            for (int i = 0; i < get(96); i++) {
                int definition = get(100) + 32 * i;
                int classIndex = get(definition);
                String descriptor = type(classIndex);
                String name = descriptor.startsWith("L") && descriptor.endsWith(";")
                    ? descriptor.substring(1, descriptor.length() - 1).replace('/', '.') : descriptor;
                if (!REFLECTIVE_CLASSES.contains(name)) continue;
                if (found.contains(name)) throw new ReleaseFailure("duplicate reflective DEX class: " + name);
                int[] cursor = { get(definition + 24) };
                if (cursor[0] == 0) throw new ReleaseFailure("missing public no-arg DEX constructor: " + name);
                int staticFields = uleb(cursor), instanceFields = uleb(cursor);
                int directMethods = uleb(cursor);
                uleb(cursor); // virtual_methods_size; constructors must be direct methods.
                for (int field = 0; field < staticFields + instanceFields; field++) { uleb(cursor); uleb(cursor); }
                boolean constructor = false;
                int methodIndex = 0;
                for (int method = 0; method < directMethods; method++) {
                    methodIndex = Math.addExact(methodIndex, uleb(cursor));
                    int access = uleb(cursor), code = uleb(cursor);
                    if (methodIndex < 0 || methodIndex >= get(88)) throw new ReleaseFailure("invalid DEX method index");
                    int id = get(92) + 8 * methodIndex;
                    if (ushort(id) != classIndex || !string(get(id + 4)).equals("<init>")) continue;
                    int protoIndex = ushort(id + 2);
                    if (protoIndex >= get(72)) throw new ReleaseFailure("invalid DEX proto index");
                    int proto = get(76) + 12 * protoIndex, parameters = get(proto + 8);
                    constructor |= (get(definition + 4) & 1) != 0 && (access & 0x10001) == 0x10001
                        && (access & 0x408) == 0 && code != 0 && type(get(proto + 4)).equals("V")
                        && (parameters == 0 || get(parameters) == 0);
                }
                if (!constructor) throw new ReleaseFailure("missing public no-arg DEX constructor: " + name);
                found.add(name);
            }
        }
    }

    static String checkConstructors(String artifact) throws Exception {
        Set<String> found = new TreeSet<>();
        Map<String, String> hashes = new TreeMap<>();
        if (artifact.endsWith(".dex")) {
            new Dex(Files.readAllBytes(Path.of(artifact))).constructors(found);
        } else {
            try (var archive = new JarFile(artifact)) {
                var entries = archive.entries();
                while (entries.hasMoreElements()) {
                    var entry = entries.nextElement();
                    if (!entry.getName().matches("(?:base/dex/)?classes(?:[2-9][0-9]*|1[0-9]+)?\\.dex")) continue;
                    try (var input = archive.getInputStream(entry)) {
                        byte[] bytes = input.readAllBytes();
                        new Dex(bytes).constructors(found);
                        String name = entry.getName().substring(entry.getName().lastIndexOf('/') + 1);
                        hashes.put(name, HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes)));
                    }
                }
            }
        }
        if (!found.containsAll(REFLECTIVE_CLASSES)) {
            var missing = new ArrayList<>(REFLECTIVE_CLASSES); missing.removeAll(found);
            throw new ReleaseFailure("missing reflective DEX classes: " + String.join(", ", missing));
        }
        StringJoiner dexHashes = new StringJoiner(",", "{", "}");
        hashes.forEach((name, hash) -> dexHashes.add("\"" + name + "\":\"" + hash + "\""));
        return "{\"publicNoArg\":true,\"classes\":[\"" + String.join("\",\"", found) + "\"],\"dexSha256\":" + dexHashes + "}";
    }

    static String inspect(String artifact, X509Certificate expected) throws Exception {
        int entries = 0, libraries = 0;
        boolean hermes = false, manifest = false, arm64 = false, arm32 = false, x64 = false;
        String sha256 = expected == null ? null : fingerprint(expected, "SHA-256");
        try (var jar = new JarFile(artifact, true)) {
            var items = jar.entries();
            while (items.hasMoreElements()) {
                JarEntry entry = items.nextElement();
                if (entry.isDirectory() || entry.getName().startsWith("META-INF/")) continue;
                try (var input = jar.getInputStream(entry)) {
                    if (entry.getName().equals("base/assets/index.android.bundle")) {
                        byte[] prefix = input.readNBytes(8);
                        hermes = prefix.length == 8 && ByteBuffer.wrap(prefix).order(ByteOrder.LITTLE_ENDIAN).getLong() == 0x1F1903C103BC1FC6L;
                    } else if (entry.getName().endsWith(".so")) {
                        try { checkNativeAlignment(input.readNBytes(65536)); }
                        catch (ReleaseFailure error) { throw new ReleaseFailure(error.getMessage() + ": " + entry.getName()); }
                        libraries++;
                        arm64 |= entry.getName().startsWith("base/lib/arm64-v8a/");
                        arm32 |= entry.getName().startsWith("base/lib/armeabi-v7a/");
                        x64 |= entry.getName().startsWith("base/lib/x86_64/");
                    }
                    input.transferTo(OutputStream.nullOutputStream()); // Triggers JAR signature/digest verification.
                }
                var certificates = entry.getCertificates();
                if (certificates == null || certificates.length == 0) throw new ReleaseFailure("unsigned AAB entry");
                String actual = fingerprint((X509Certificate) certificates[0], "SHA-256");
                if (sha256 == null) sha256 = actual;
                if (!actual.equals(sha256)) throw new ReleaseFailure("AAB signer does not match existing upload key");
                manifest |= entry.getName().equals("base/manifest/AndroidManifest.xml");
                entries++;
            }
        }
        if (!hermes || !manifest || libraries == 0 || entries == 0) throw new ReleaseFailure("incomplete release AAB or missing Hermes bytecode");
        return ",\"constructors\":" + checkConstructors(artifact) + ",\"verifiedEntries\":" + entries + ",\"nativeLibraries\":" + libraries +
            ",\"hermes\":true,\"arm64\":" + arm64 + ",\"arm32\":" + arm32 + ",\"x64\":" + x64;
    }

    public static void main(String[] args) {
        try {
            if (args.length == 2 && args[0].equals("constructors")) {
                System.out.println(checkConstructors(args[1]));
                return;
            }
            if (args.length == 2 && args[0].equals("inspect")) {
                System.out.println("{\"signatureVerified\":true" + inspect(args[1], null) + "}");
                return;
            }
            if (args.length < 3 || !args[0].equals("signing")) throw new ReleaseFailure("invalid release verification arguments");
            X509Certificate cert = signingCertificate(args[1], args[2]);
            String artifact = args.length == 4 ? inspect(args[3], cert) : "";
            System.out.println("{\"sha1\":\"" + fingerprint(cert, "SHA-1") + "\",\"sha256\":\"" +
                fingerprint(cert, "SHA-256") + "\"" + artifact + "}");
        } catch (Exception error) {
            // Never print a lower-level exception, properties, aliases, or credentials.
            System.err.println(error instanceof ReleaseFailure ? "Release verification failed: " + error.getMessage() :
                "Release verification failed: check Java signing properties, existing keystore/passwords, certificate validity and artifact integrity.");
            System.exit(1);
        }
    }
}
