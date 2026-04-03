/* fonts.vala - Font scanning (simplified) */

public class FontScanner : Object {
    public string[] families { get; private set; }
    
    public FontScanner() {
        families = {"DejaVu Sans", "DejaVu Serif", "Monospace", "Sans", "Serif"};
    }
    
    public void scan() {
        // Simplified static list
    }
}
