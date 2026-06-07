package watermark

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"strings"
)

// VideoTags carries MP4 udta deep-synthesis markers.
type VideoTags struct {
	Producer string
	Model    string
	FilingNo string
	Source   string
}

// ApplyVideo injects udta metadata into an MP4 container.
func ApplyVideo(data []byte, tags VideoTags) ([]byte, error) {
	if !isMP4(data) {
		return nil, fmt.Errorf("not an MP4 video")
	}
	return injectMP4Udta(data, tags)
}

func isMP4(data []byte) bool {
	if len(data) < 12 {
		return false
	}
	typ := string(data[4:8])
	return typ == "ftyp" || typ == "moov" || typ == "mdat"
}

type mp4Box struct {
	size int
	typ  string
	data []byte
}

func parseTopLevelBoxes(data []byte) ([]mp4Box, error) {
	var boxes []mp4Box
	pos := 0
	for pos+8 <= len(data) {
		size := int(binary.BigEndian.Uint32(data[pos : pos+4]))
		typ := string(data[pos+4 : pos+8])
		if size < 8 {
			return nil, fmt.Errorf("invalid box size for %s", typ)
		}
		if pos+size > len(data) {
			return nil, fmt.Errorf("truncated box %s", typ)
		}
		boxes = append(boxes, mp4Box{
			size: size,
			typ:  typ,
			data: data[pos : pos+size],
		})
		pos += size
	}
	return boxes, nil
}

func injectMP4Udta(data []byte, tags VideoTags) ([]byte, error) {
	boxes, err := parseTopLevelBoxes(data)
	if err != nil {
		return nil, err
	}

	udta := buildUdtaBox(tags)
	moovFound := false
	for i, box := range boxes {
		if box.typ == "moov" {
			moovFound = true
			updated, err := upsertMoovUdta(box.data, udta)
			if err != nil {
				return nil, err
			}
			boxes[i].data = updated
			boxes[i].size = len(updated)
			break
		}
	}
	if !moovFound {
		moov := buildMinimalMoov(udta)
		boxes = append(boxes, mp4Box{typ: "moov", data: moov, size: len(moov)})
	}

	var out bytes.Buffer
	for _, box := range boxes {
		out.Write(box.data)
	}
	return out.Bytes(), nil
}

func upsertMoovUdta(moov []byte, udta []byte) ([]byte, error) {
	if len(moov) < 8 {
		return nil, fmt.Errorf("invalid moov box")
	}
	children, err := parseChildBoxes(moov[8:])
	if err != nil {
		return nil, err
	}
	replaced := false
	for i, child := range children {
		if child.typ == "udta" {
			children[i].data = udta
			children[i].size = len(udta)
			replaced = true
			break
		}
	}
	if !replaced {
		children = append(children, mp4Box{typ: "udta", data: udta, size: len(udta)})
	}
	return rebuildBox("moov", children), nil
}

func parseChildBoxes(data []byte) ([]mp4Box, error) {
	var boxes []mp4Box
	pos := 0
	for pos+8 <= len(data) {
		size := int(binary.BigEndian.Uint32(data[pos : pos+4]))
		typ := string(data[pos+4 : pos+8])
		if size < 8 || pos+size > len(data) {
			return nil, fmt.Errorf("invalid child box %s", typ)
		}
		boxes = append(boxes, mp4Box{
			size: size,
			typ:  typ,
			data: data[pos : pos+size],
		})
		pos += size
	}
	return boxes, nil
}

func rebuildBox(typ string, children []mp4Box) []byte {
	payloadSize := 8
	for _, child := range children {
		payloadSize += child.size
	}
	out := make([]byte, payloadSize)
	binary.BigEndian.PutUint32(out[0:4], uint32(payloadSize))
	copy(out[4:8], typ)
	pos := 8
	for _, child := range children {
		copy(out[pos:], child.data)
		pos += child.size
	}
	return out
}

func buildMinimalMoov(udta []byte) []byte {
	return rebuildBox("moov", []mp4Box{{typ: "udta", data: udta, size: len(udta)}})
}

func buildUdtaBox(tags VideoTags) []byte {
	meta := buildMetaBox(tags)
	return rebuildBox("udta", []mp4Box{{typ: "meta", data: meta, size: len(meta)}})
}

func buildMetaBox(tags VideoTags) []byte {
	hdlr := buildHdlrBox()
	ilst := buildIlstBox(tags)
	return rebuildBox("meta", []mp4Box{
		{typ: "hdlr", data: hdlr, size: len(hdlr)},
		{typ: "ilst", data: ilst, size: len(ilst)},
	})
}

func buildHdlrBox() []byte {
	payload := make([]byte, 21)
	copy(payload[8:12], "mdir")
	return rebuildFullBox("hdlr", payload)
}

func buildIlstBox(tags VideoTags) []byte {
	comment := UdtaJSONComment(tags)
	return rebuildBox("ilst", []mp4Box{
		buildIlstDataItem("©too", tags.Producer),
		buildIlstDataItem("©cmt", comment),
		buildIlstDataItem("----", "AIGC-Model="+tags.Model),
	})
}

func buildIlstDataItem(fourcc, value string) mp4Box {
	dataBox := buildDataPayload(value)
	itemData := rebuildBox(fourcc, []mp4Box{{typ: "data", data: dataBox, size: len(dataBox)}})
	return mp4Box{typ: fourcc, data: itemData, size: len(itemData)}
}

func buildDataPayload(text string) []byte {
	payload := make([]byte, 8+len(text))
	payload[4] = 1 // UTF-8
	copy(payload[8:], []byte(text))
	box := rebuildFullBox("data", payload)
	return box
}

func rebuildFullBox(typ string, payload []byte) []byte {
	size := 8 + len(payload)
	out := make([]byte, size)
	binary.BigEndian.PutUint32(out[0:4], uint32(size))
	copy(out[4:8], typ)
	copy(out[8:], payload)
	return out
}

// HasMP4UdtaMarker reports whether injected AIGC tags are present.
func HasMP4UdtaMarker(data []byte, model string) bool {
	return bytes.Contains(data, []byte("AIGC-Model")) && bytes.Contains(data, []byte(model))
}

// MinimalMP4 returns a tiny valid MP4 for unit tests.
func MinimalMP4() []byte {
	ftyp := make([]byte, 24)
	binary.BigEndian.PutUint32(ftyp[0:4], 24)
	copy(ftyp[4:8], "ftyp")
	copy(ftyp[8:12], "isom")
	binary.BigEndian.PutUint32(ftyp[12:16], 0x20000)
	copy(ftyp[16:20], "isom")
	copy(ftyp[20:24], "iso2")

	mdat := make([]byte, 16)
	binary.BigEndian.PutUint32(mdat[0:4], 16)
	copy(mdat[4:8], "mdat")

	moov := buildMinimalMoov(buildUdtaBox(VideoTags{Producer: "baobao", Model: "test", Source: "AIGC:baobao/test"}))
	return append(append(ftyp, mdat...), moov...)
}

// UdtaJSONComment returns a compact JSON summary stored in udta for inspection.
func UdtaJSONComment(tags VideoTags) string {
	return fmt.Sprintf(`{"AIGC-Producer":%q,"AIGC-Model":%q,"AIGC-FilingNo":%q,"AIGC-Source":%q}`,
		tags.Producer, tags.Model, tags.FilingNo, tags.Source)
}

// HasVideoMarker is a test helper combining byte markers.
func HasVideoMarker(data []byte, tags VideoTags) bool {
	return strings.Contains(string(data), tags.Model) && strings.Contains(string(data), "AIGC-Producer")
}
