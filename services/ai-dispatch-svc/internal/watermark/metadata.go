package watermark

import (
	"encoding/binary"
	"fmt"
	"hash/crc32"
	"strings"
)

const (
	pngSignature = "\x89PNG\r\n\x1a\n"
	xmpNamespace = "http://purl.org/dc/elements/1.1/"
)

// buildXMP returns an XMP packet with dc:Source deep-synthesis marker.
func buildXMP(source string) string {
	escaped := strings.ReplaceAll(source, "&", "&amp;")
	return fmt.Sprintf(`<?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?>`+
		`<x:xmpmeta xmlns:x="adobe:ns:meta/">`+
		`<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">`+
		`<rdf:Description rdf:about="" xmlns:dc="%s">`+
		`<dc:Source>%s</dc:Source>`+
		`</rdf:Description>`+
		`</rdf:RDF>`+
		`</x:xmpmeta>`+
		`<?xpacket end="w"?>`, xmpNamespace, escaped)
}

// buildEXIFUserComment returns a minimal EXIF blob with UserComment carrying the source tag.
func buildEXIFUserComment(source string) []byte {
	comment := []byte(source)
	// TIFF header (MM), IFD0 with one UserComment tag (0x9286).
	const ifdOffset = 8
	buf := make([]byte, 0, 128)
	buf = append(buf, 'M', 'M', 0, 42)
	tmp := make([]byte, 4)
	binary.BigEndian.PutUint32(tmp, ifdOffset)
	buf = append(buf, tmp...)

	// IFD: 1 entry
	binary.BigEndian.PutUint32(tmp, 1)
	buf = append(buf, tmp...)
	// Tag UserComment
	binary.BigEndian.PutUint16(tmp[:2], 0x9286)
	buf = append(buf, tmp[:2]...)
	binary.BigEndian.PutUint16(tmp[:2], 2) // ASCII
	buf = append(buf, tmp[:2]...)
	binary.BigEndian.PutUint32(tmp, uint32(len(comment)+1))
	buf = append(buf, tmp...)
	dataOffset := uint32(len(buf) + 4 + 2) // after next IFD pointer + count bytes
	binary.BigEndian.PutUint32(tmp, dataOffset)
	buf = append(buf, tmp...)
	binary.BigEndian.PutUint32(tmp, 0) // next IFD
	buf = append(buf, tmp...)
	buf = append(buf, comment...)
	buf = append(buf, 0)
	return buf
}

func pngChunk(typ string, data []byte) []byte {
	out := make([]byte, 8+len(data)+4)
	binary.BigEndian.PutUint32(out[0:4], uint32(len(data)))
	copy(out[4:8], typ)
	copy(out[8:], data)
	crc := crc32.ChecksumIEEE(append([]byte(typ), data...))
	binary.BigEndian.PutUint32(out[8+len(data):], crc)
	return out
}

// embedPNGMetadata inserts XMP (iTXt) and EXIF (eXIf) chunks before IEND.
func embedPNGMetadata(pngData []byte, source string) ([]byte, error) {
	if len(pngData) < 8 || string(pngData[:8]) != pngSignature {
		return nil, fmt.Errorf("not a PNG image")
	}

	xmp := buildXMP(source)
	xmpKeyword := "XML:com.adobe.xmp"
	xmpPayload := append([]byte(xmpKeyword), 0) // keyword + null
	xmpPayload = append(xmpPayload, 0, 0)     // compression flag + method
	xmpPayload = append(xmpPayload, 0)        // language tag empty
	xmpPayload = append(xmpPayload, 0)        // translated keyword empty
	xmpPayload = append(xmpPayload, []byte(xmp)...)

	exif := buildEXIFUserComment(source)
	extra := append(pngChunk("iTXt", xmpPayload), pngChunk("eXIf", exif)...)

	iendPos := -1
	for pos := 8; pos+12 <= len(pngData); {
		length := int(binary.BigEndian.Uint32(pngData[pos : pos+4]))
		typ := string(pngData[pos+4 : pos+8])
		if typ == "IEND" {
			iendPos = pos
			break
		}
		pos += 12 + length
	}
	if iendPos < 0 {
		return nil, fmt.Errorf("PNG missing IEND")
	}

	out := make([]byte, 0, len(pngData)+len(extra))
	out = append(out, pngData[:iendPos]...)
	out = append(out, extra...)
	out = append(out, pngData[iendPos:]...)
	return out, nil
}

// embedJPEGMetadata prepends APP1 EXIF and APP1 XMP segments after SOI.
func embedJPEGMetadata(jpegData []byte, source string) ([]byte, error) {
	if len(jpegData) < 2 || jpegData[0] != 0xFF || jpegData[1] != 0xD8 {
		return nil, fmt.Errorf("not a JPEG image")
	}

	exif := buildEXIFUserComment(source)
	exifSegment := buildJPEGAPP1("Exif\x00\x00", exif)

	xmp := buildXMP(source)
	xmpGUID := "http://ns.adobe.com/xap/1.0/\x00"
	xmpSegment := buildJPEGAPP1(xmpGUID, []byte(xmp))

	var out []byte
	out = append(out, 0xFF, 0xD8)
	out = append(out, exifSegment...)
	out = append(out, xmpSegment...)
	out = append(out, jpegData[2:]...)
	return out, nil
}

func buildJPEGAPP1(identifier string, payload []byte) []byte {
	content := append([]byte(identifier), payload...)
	size := len(content) + 2
	if size > 0xFFFF {
		panic("APP1 segment too large")
	}
	seg := make([]byte, 2+size)
	seg[0] = 0xFF
	seg[1] = 0xE1
	binary.BigEndian.PutUint16(seg[2:], uint16(size))
	copy(seg[4:], content)
	return seg
}
