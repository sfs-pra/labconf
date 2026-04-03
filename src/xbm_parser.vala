/* xbm_parser.vala - XBM parser for titlebar buttons */
public class XbmBitmap : Object {
    public int width { get; private set; }
    public int height { get; private set; }
    private uint8[] pixels;

    public XbmBitmap(int width, int height, uint8[] pixels) {
        this.width = width;
        this.height = height;
        this.pixels = pixels;
    }

    public bool has_pixels() {
        return pixels.length == width * height;
    }

    public bool get_pixel(int x, int y) {
        if (x < 0 || y < 0 || x >= width || y >= height) {
            return false;
        }
        return pixels[y * width + x] != 0;
    }
}

public class XbmParser : Object {
    public static XbmBitmap? parse_xbm(string path) {
        if (!FileUtils.test(path, FileTest.EXISTS)) {
            return null;
        }

        try {
            string content;
            FileUtils.get_contents(path, out content);

            int width = parse_define(content, "_width");
            int height = parse_define(content, "_height");
            if (width <= 0 || height <= 0) {
                return null;
            }

            uint8[] bytes = parse_data_bytes(content);
            if (bytes.length == 0) {
                return null;
            }

            int row_bytes = (width + 7) / 8;
            int required_bytes = row_bytes * height;
            if (bytes.length < required_bytes) {
                return null;
            }

            uint8[] pixels = new uint8[width * height];
            for (int y = 0; y < height; y++) {
                for (int x = 0; x < width; x++) {
                    int byte_index = y * row_bytes + (x / 8);
                    int bit_index = x % 8;
                    uint8 value = bytes[byte_index];
                    pixels[y * width + x] = ((value >> bit_index) & 0x01) != 0 ? (uint8)1 : (uint8)0;
                }
            }

            return new XbmBitmap(width, height, pixels);
        } catch (Error e) {
            return null;
        }
    }

    public static XbmBitmap? load_button_icon(string openbox_dir, string button_name) {
        if (openbox_dir == "") {
            return null;
        }
        string xbm_path = Path.build_filename(openbox_dir, button_name + ".xbm");
        return parse_xbm(xbm_path);
    }

    private static int parse_define(string content, string suffix) {
        string[] lines = content.split("\n");
        foreach (string line_raw in lines) {
            string line = line_raw.strip();
            if (!line.has_prefix("#define")) {
                continue;
            }
            if (!line.contains(suffix)) {
                continue;
            }
            string[] parts = line.split(" ");
            if (parts.length < 3) {
                continue;
            }
            int parsed = 0;
            if (int.try_parse(parts[parts.length - 1].strip(), out parsed)) {
                return parsed;
            }
        }
        return 0;
    }

    private static uint8[] parse_data_bytes(string content) {
        int start = content.index_of("{");
        int end = content.last_index_of("}");
        if (start < 0 || end <= start) {
            return {};
        }

        string body = content.substring(start + 1, end - start - 1);
        string[] tokens = body.split(",");
        uint8[] bytes = {};

        foreach (string token_raw in tokens) {
            string token = token_raw.strip();
            if (token == "") {
                continue;
            }
            uint8 value = parse_byte_token(token);
            bytes += value;
        }

        return bytes;
    }

    private static uint8 parse_byte_token(string token) {
        string t = token.strip();
        int start = 0;
        if (t.has_prefix("0x") || t.has_prefix("0X")) {
            start = 2;
        }

        uint value = 0;
        for (int i = start; i < t.length; i++) {
            int nibble = hex_value(t.get_char(i));
            if (nibble < 0) {
                break;
            }
            value = (value << 4) + (uint)nibble;
        }

        return (uint8)(value & 0xff);
    }

    private static int hex_value(unichar c) {
        if (c >= '0' && c <= '9') {
            return (int)(c - '0');
        }
        if (c >= 'a' && c <= 'f') {
            return 10 + (int)(c - 'a');
        }
        if (c >= 'A' && c <= 'F') {
            return 10 + (int)(c - 'A');
        }
        return -1;
    }
}
