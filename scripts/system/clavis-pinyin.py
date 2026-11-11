#!/usr/bin/env python3
"""Small offline pinyin candidate helper for the Clavis touch keyboard.

The IBus Wayland input method handles physical keyboards.  The touch keyboard
uses wtype, which bypasses the input-method keyboard grab, so it asks libpinyin
for candidates directly and sends the chosen UTF-8 text through wtype.
"""
import ctypes
import ctypes.util
import glob
import json
import os
import sys

LIB = ctypes.util.find_library("pinyin") or "/usr/lib/aarch64-linux-gnu/libpinyin.so.15"
_data_candidates = sorted(glob.glob("/usr/lib/*/libpinyin/data")) + ["/usr/lib/libpinyin/data"]
DATA = next((path for path in _data_candidates if os.path.isdir(path)), "/usr/lib/aarch64-linux-gnu/libpinyin/data")


def load_library():
    lib = ctypes.CDLL(LIB)
    lib.pinyin_init.argtypes = [ctypes.c_char_p, ctypes.c_char_p]
    lib.pinyin_init.restype = ctypes.c_void_p
    lib.pinyin_alloc_instance.argtypes = [ctypes.c_void_p]
    lib.pinyin_alloc_instance.restype = ctypes.c_void_p
    lib.pinyin_parse_more_full_pinyins.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
    lib.pinyin_parse_more_full_pinyins.restype = ctypes.c_size_t
    lib.pinyin_reset.argtypes = [ctypes.c_void_p]
    lib.pinyin_reset.restype = None
    lib.pinyin_guess_candidates.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_uint]
    lib.pinyin_guess_candidates.restype = ctypes.c_bool
    lib.pinyin_get_parsed_input_length.argtypes = [ctypes.c_void_p]
    lib.pinyin_get_parsed_input_length.restype = ctypes.c_size_t
    lib.pinyin_get_n_candidate.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_uint)]
    lib.pinyin_get_n_candidate.restype = ctypes.c_bool
    lib.pinyin_get_candidate.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.POINTER(ctypes.c_void_p)]
    lib.pinyin_get_candidate.restype = ctypes.c_bool
    lib.pinyin_get_candidate_string.argtypes = [ctypes.c_void_p, ctypes.c_void_p,
                                                ctypes.POINTER(ctypes.c_char_p)]
    lib.pinyin_get_candidate_string.restype = ctypes.c_bool
    lib.pinyin_free_instance.argtypes = [ctypes.c_void_p]
    lib.pinyin_fini.argtypes = [ctypes.c_void_p]
    return lib


T9_GROUPS = {
    "2": "abc",
    "3": "def",
    "4": "ghi",
    "5": "jkl",
    "6": "mno",
    "7": "pqrs",
    "8": "tuv",
    "9": "wxyz",
}


PINYIN_SYLLABLES = """
a ai an ang ao ba bai ban bang bao bei ben beng bi bian biang biao bie bin bing bo bong bu
ca cai can cang cao ce cei cen ceng cha chai chan chang chao che chen cheng chi chong chou
chu chua chuai chuan chuang chui chun chuo ci cong cou cu cuan cui cun cuo
da dai dan dang dao de dei den deng di dia dian diao die din ding diu dong dou du duan dui
dun duo e ei en eng er fa fan fang fei fen feng fiao fo fou fu
ga gai gan gang gao ge gei gen geng gong gou gu gua guai guan guang gui gun guo
ha hai han hang hao he hei hen heng hm hng hong hou hu hua huai huan huang hui hun huo
ji jia jian jiang jiao jie jin jing jiong jiu ju juan jue jun
ka kai kan kang kao ke kei ken keng kong kou ku kua kuai kuan kuang kui kun kuo
la lai lan lang lao le lei len leng li lia lian liang liao lie lin ling liu lo long lou lu
luan lue lun luo m ma mai man mang mao me mei men meng mi mian miao mie min ming miu mo mou mu
n na nai nan nang nao ne nei nen neng ng ni nia nian niang niao nie nin ning niu nong nou nu
nuan nue nun nuo o ou pa pai pan pang pao pei pen peng pi pian piao pie pin ping po pou pu
qi qia qian qiang qiao qie qin qing qiong qiu qu quan que qun
ran rang rao re ren reng ri rong rou ru rua ruan rui run ruo
sa sai san sang sao se sen seng sha shai shan shang shao she shei shen sheng shi shou shu
shua shuai shuan shuang shui shun shuo si song sou su suan sui sun suo
ta tai tan tang tao te tei teng ti tian tiao tie ting tong tou tu tuan tui tun tuo
wa wai wan wang wei wen weng wo wong wu xi xia xian xiang xiao xie xin xing xiong xiu xu
xuan xue xun ya yan yang yao ye yi yin ying yo yong you yu yuan yue yun
za zai zan zang zao ze zei zen zeng zha zhai zhan zhang zhao zhe zhei zhen zheng zhi zhong
zhou zhu zhua zhuai zhuan zhuang zhui zhun zhuo zi zong zou zu zuan zui zun zuo
""".split()


def t9_digits_for(text):
    reverse = {}
    for digit, letters in T9_GROUPS.items():
        for letter in letters:
            reverse[letter] = digit
    return "".join(reverse[letter] for letter in text if letter in reverse)


T9_BY_SYLLABLE = {}
for _syllable in PINYIN_SYLLABLES:
    T9_BY_SYLLABLE.setdefault(t9_digits_for(_syllable), []).append(_syllable)

# A tiny prior for the most common short messages. Pinyin candidates from
# libpinyin are ordered by its own phrase model; these users almost always
# expect the everyday word first when the T9 spelling is exact.
T9_BOOST = {
    "64426": ["你好"],
    "94664936": ["中文"],
    "96636": ["我们"],
    "548744": ["就是"],
    "943943": ["谢谢"],
    "743663": ["什么"],
    "5394": ["可以"],
    "28744": ["不是"],
    "5468426": ["今天"],
    "42633": ["好的"],
}


def t9_segmentations(digits, limit=512):
    if not digits or any(digit not in T9_GROUPS for digit in digits):
        return []

    segmented = []

    def segment(position, syllables):
        if len(segmented) >= limit:
            return
        if position == len(digits):
            segmented.append(tuple(syllables))
            return
        # Longest syllable first: this finds natural phrases such as
        # "zhong wen" before exhausting thousands of one-letter splits.
        for end in range(min(len(digits), position + 6), position, -1):
            for syllable in T9_BY_SYLLABLE.get(digits[position:end], []):
                segment(end, syllables + [syllable])

    segment(0, [])
    seen = set()
    result = []
    for item in segmented:
        if item not in seen:
            seen.add(item)
            result.append(item)
    return result


def t9_letter_combinations(digits, limit=64):
    result = [""]
    for digit in digits:
        result = [prefix + letter for prefix in result for letter in T9_GROUPS[digit]]
        if len(result) > limit:
            result = result[:limit]
    return result


def candidate_strings(lib, instance, text, limit=10):
    lib.pinyin_reset(instance)
    candidates = []
    if lib.pinyin_parse_more_full_pinyins(instance, text.encode()) <= 0:
        return candidates, 0
    parsed = lib.pinyin_get_parsed_input_length(instance)
    lib.pinyin_guess_candidates(instance, 0, 0x14)
    count = ctypes.c_uint()
    if lib.pinyin_get_n_candidate(instance, ctypes.byref(count)):
        for index in range(min(count.value, limit * 3)):
            candidate = ctypes.c_void_p()
            value = ctypes.c_char_p()
            if lib.pinyin_get_candidate(instance, index, ctypes.byref(candidate)) \
                    and lib.pinyin_get_candidate_string(instance, candidate, ctypes.byref(value)) \
                    and value.value:
                candidates.append(value.value.decode("utf-8", "replace"))
    # libpinyin ranks longer phrase guesses above the character that actually
    # matches the typed syllables ("阿尔" before "啊"). Keep candidates that fit
    # the parsed input first and fall back to longer guesses afterwards.
    syllables = max(1, syllable_count(text[:parsed])) if parsed else 1
    fitting = [candidate for candidate in candidates if len(candidate) <= syllables]
    if fitting:
        candidates = fitting + [candidate for candidate in candidates if len(candidate) > syllables]
    return candidates[:limit], parsed


def syllable_count(text):
    vocabulary = set(PINYIN_SYLLABLES)
    best = [len(text) + 1] * (len(text) + 1)
    best[0] = 0
    for index in range(len(text)):
        if best[index] > len(text):
            continue
        for length in range(1, min(6, len(text) - index) + 1):
            if text[index:index + length] in vocabulary:
                best[index + length] = min(best[index + length], best[index] + 1)
    return best[len(text)]


def nine_key_candidates(lib, instance, digits):
    segmentations = t9_segmentations(digits)
    scored = []
    if segmentations:
        # Prefer the smallest number of syllables, then let candidate quality
        # decide between competing segmentations.  Sixteen alternatives are
        # enough for the candidate rail and keep a keystroke responsive.
        segmentations.sort(key=lambda syllables: (len(syllables), len("".join(syllables)), " ".join(syllables)))
        for syllables in segmentations[:64]:
            text = "".join(syllables)
            candidates, parsed = candidate_strings(lib, instance, text, 12)
            if not candidates:
                continue
            full_count = sum(1 for candidate in candidates if len(candidate) == len(syllables))
            boost = 0
            for preferred in T9_BOOST.get(digits, []):
                if preferred in candidates:
                    boost = 2
                    break
            score = (boost, full_count, len(candidates[0]), -len(syllables), len(candidates),
                     1 if parsed == len(text) else 0)
            scored.append((score, {
                "text": " ".join(syllables),
                "syllables": list(syllables),
                "digitGroups": [t9_digits_for(syllable) for syllable in syllables],
                "candidates": candidates
            }))
        if scored:
            scored.sort(key=lambda item: item[0], reverse=True)
            segments = [item[1] for item in scored[:24]]
            return {
                "preedit": segments[0]["text"],
                "segments": segments,
                "candidates": segments[0]["candidates"]
            }

    # Incomplete or unsegmentable input still gets useful candidates from the
    # raw letter combinations, without pretending to know syllable boundaries.
    best = None
    for text in t9_letter_combinations(digits, 16):
        candidates, parsed = candidate_strings(lib, instance, text, 12)
        if not candidates:
            continue
        score = (1 if parsed == len(text) else 0, len(candidates))
        if best is None or score > best[0]:
            best = (score, {
                "text": text,
                "syllables": [text],
                "digitGroups": [digits],
                "candidates": candidates
            })
    if best is not None:
        segment = best[1]
        return {
            "preedit": segment["text"],
            "segments": [segment],
            "candidates": segment["candidates"]
        }
    return {
        "preedit": "",
        "segments": [],
        "candidates": []
    }


def main():
    args = sys.argv[1:]
    nine_key = bool(args and args[0] == "--t9")
    text = (args[1] if nine_key and len(args) > 1 else "".join(args if not nine_key else [])).strip().lower()
    if nine_key:
        if not text or not text.isdigit() or any(digit not in T9_GROUPS for digit in text):
            print("[]")
            return
    elif not text or not text.isascii() or not text.isalpha():
        print("[]")
        return

    lib = load_library()
    userdir = os.path.expanduser("~/.cache/clavis-pinyin")
    os.makedirs(userdir, exist_ok=True)
    context = lib.pinyin_init(DATA.encode(), userdir.encode())
    if not context:
        print("[]")
        return
    instance = lib.pinyin_alloc_instance(context)
    if not instance:
        lib.pinyin_fini(context)
        print("[]")
        return

    try:
        if nine_key:
            result = nine_key_candidates(lib, instance, text)
        else:
            result = candidate_strings(lib, instance, text, 12)[0]
    finally:
        lib.pinyin_free_instance(instance)
        lib.pinyin_fini(context)

    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
