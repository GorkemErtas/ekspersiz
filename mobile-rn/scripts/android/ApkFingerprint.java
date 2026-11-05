import java.nio.charset.StandardCharsets;
import java.util.zip.ZipFile;

/** Read the same packaged asset as Expo's Android UpdatesConfiguration. */
class ApkFingerprint {
    public static void main(String[] args) {
        try {
            if (args.length != 1) throw new IllegalArgumentException("one APK path is required");
            try (var archive = new ZipFile(args[0])) {
                var entries = archive.stream()
                    .filter(entry -> entry.getName().equals("assets/fingerprint"))
                    .toList();
                if (entries.size() != 1 || entries.getFirst().isDirectory())
                    throw new IllegalArgumentException("exactly one assets/fingerprint is required");
                try (var input = archive.getInputStream(entries.getFirst())) {
                    // Bound decompression and reject trailing bytes, including newlines.
                    String fingerprint = new String(input.readNBytes(41), StandardCharsets.UTF_8);
                    if (!fingerprint.matches("[0-9a-f]{40}"))
                        throw new IllegalArgumentException("assets/fingerprint must contain exactly 40 lowercase hex characters");
                    System.out.print(fingerprint);
                }
            }
        } catch (Exception error) {
            System.err.println(error.getMessage());
            System.exit(1);
        }
    }
}
