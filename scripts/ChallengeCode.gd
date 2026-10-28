extends RefCounted
## Код вызова «ОМСК-XXXXX-XXXXX»: 10 символов, 50 бит.
## Внутри: трасса (5 бит), машина (6), сложность (2), зерно трафика (16), счёт ÷ 10 (15)
## и контрольная сумма (6). Интернет не нужен — всё зашито в сам код.
## Алфавит без похожих символов (нет 0/O, 1/I), русские буквы-двойники понимаются как латинские.

const ALPHABET := "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"
const PREFIX := "ОМСК"
const DIFFS := ["easy", "normal", "hard"]
const LOOKALIKE := {"А": "A", "В": "B", "Е": "E", "К": "K", "М": "M", "Н": "H", "Р": "P", "С": "C",
	"Т": "T", "Х": "X", "У": "Y", "Ё": "E", "З": "3", "О": "", "0": "", "O": "", "I": "1", "Ь": "B"}


static func _index_of(list: Array, id: String) -> int:
	for i in list.size():
		if list[i].id == id:
			return i
	return -1


static func _checksum(v: int) -> int:
	var x := v * 2654435761 + 40503
	x = (x ^ (x >> 13)) * 1274126177
	return (x >> 7) & 63


static func encode(loc_id: String, car_id: String, diff_id: String, seed: int, score: int) -> String:
	var li := maxi(_index_of(GameData.LOCATIONS, loc_id), 0)
	var ci := maxi(_index_of(GameData.CARS, car_id), 0)
	var di := maxi(DIFFS.find(diff_id), 0)
	var sc := clampi(int(round(score / 10.0)), 0, 32767)
	var v := li & 31
	v = (v << 6) | (ci & 63)
	v = (v << 2) | di
	v = (v << 16) | (seed & 0xFFFF)
	v = (v << 15) | sc
	v = (v << 6) | _checksum(v)
	var chars := ""
	for i in 10:
		chars = ALPHABET[v & 31] + chars
		v >>= 5
	return "%s-%s-%s" % [PREFIX, chars.substr(0, 5), chars.substr(5, 5)]


## Разбор кода. Возвращает {} при ошибке, иначе {"loc", "car", "diff", "seed", "score"}
static func decode(text: String) -> Dictionary:
	var t := text.strip_edges().to_upper()
	for pre in ["ОМСК", "OMSK", "OMCK"]:
		if t.begins_with(pre):
			t = t.substr(pre.length())
			break
	var clean := ""
	for ch in t:
		if LOOKALIKE.has(ch):
			ch = LOOKALIKE[ch]
		if ch != "" and ALPHABET.contains(ch):
			clean += ch
	if clean.length() != 10:
		return {}
	var v := 0
	for ch in clean:
		v = (v << 5) | ALPHABET.find(ch)
	var sum := v & 63
	v >>= 6
	if _checksum(v) != sum:
		return {}
	var sc := v & 32767
	v >>= 15
	var seed := v & 0xFFFF
	v >>= 16
	var di := v & 3
	v >>= 2
	var ci := v & 63
	v >>= 6
	var li := v & 31
	if li >= GameData.LOCATIONS.size() or ci >= GameData.CARS.size() or di >= DIFFS.size():
		return {}
	return {"loc": GameData.LOCATIONS[li].id, "car": GameData.CARS[ci].id, "diff": DIFFS[di],
		"seed": seed, "score": sc * 10}
