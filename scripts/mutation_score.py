import re, sys, json

def main(path):
    text = open(path).read()
    m = re.search(r"(\d+)\s*/\s*(\d+)\s*mutants", text)
    score = (int(m.group(1))/int(m.group(2))*100) if m else None
    out = {"mutants_killed": m.group(1) if m else None, "mutants_total": m.group(2) if m else None, "score_pct": score}
    print(json.dumps(out, indent=2))

if __name__ == "__main__":
    main(sys.argv[1])
