import os
import sys
import sqlite3
import json
import regex as re
import subprocess
from pathlib import Path

from datasets import load_dataset
from transformers import AutoTokenizer, AutoModelForCausalLM, TrainingArguments, Trainer
from peft import get_peft_model, LoraConfig, TaskType, prepare_model_for_kbit_training, PeftModel

# === ARGS ===
model_id = sys.argv[1]
output_dir = sys.argv[2]
db_paths = sys.argv[3:]

final_jsonl = f"{output_dir}/bible.jsonl"
merged_dir = f"{output_dir}/merged"
gguf_path = f"{output_dir}/gguf"

Path(output_dir).mkdir(parents=True, exist_ok=True)

# === 1. EXPORT FROM SQLITE ===
def clean_text(text):
    if not text:
        return ""
    # Remove all XML/HTML-style tags with content inside
    text = re.sub(r'<[^>]+>.*?</[^>]+>', '', text, flags=re.DOTALL)
    # Remove singleton tags like <br/>
    text = re.sub(r'<[^>/]+\s*/?>', '', text)
    # Remove non-letter, non-space, non-punctuation characters
    text = re.sub(r'[^\p{L}\p{P}\p{Z}]', '', text, flags=re.UNICODE)
    # Collapse multiple spaces
    text = re.sub(r'\s+', ' ', text)
    return text.strip()

def export_bible_to_jsonl(db_path, lang_code, out_file):
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()

    query = """
    SELECT address, text, source FROM _all_verses
    ORDER BY book_number, chapter, verse
    """

    with open(out_file, 'w', encoding='utf-8') as f:
        for address, verse_text, source in cur.execute(query):
            if verse_text is None:
                continue
            prompt = f"[{lang_code.upper()}] {address} ({source})"
            completion = clean_text(verse_text)
            json.dump({"prompt": prompt, "completion": completion}, f)
            f.write('\n')
    conn.close()

print("Exporting JSONL...")
jsonl_parts = []
for db_path in db_paths:
    lang = Path(db_path).stem
    out_file = f"{output_dir}/bible_{lang}.jsonl"
    export_bible_to_jsonl(db_path, lang, out_file)
    jsonl_parts.append(out_file)

with open(final_jsonl, 'w', encoding='utf-8') as fout:
    for part in jsonl_parts:
        with open(part, 'r', encoding='utf-8') as fin:
            fout.write(fin.read())

# === 2. TRAINING WITH LoRA ===
print("Training model with LoRA...")

tokenizer = AutoTokenizer.from_pretrained(model_id, trust_remote_code=True)
dataset = load_dataset("json", data_files=final_jsonl)["train"]

def tokenize(example):
    encoded = tokenizer(
        f"{example['prompt']}\n{example['completion']}",
        truncation=True,
        padding="max_length",
        max_length=512
    )
    encoded["labels"] = encoded["input_ids"].copy()
    return encoded

tokenized_dataset = dataset.map(tokenize)

model = AutoModelForCausalLM.from_pretrained(model_id)
model = prepare_model_for_kbit_training(model)

lora_config = LoraConfig(
    r=8,
    lora_alpha=16,
    target_modules=["q_proj", "v_proj"],
    lora_dropout=0.1,
    bias="none",
    task_type=TaskType.CAUSAL_LM
)

model = get_peft_model(model, lora_config)

training_args = TrainingArguments(
    output_dir=output_dir,
    per_device_train_batch_size=2,
    num_train_epochs=1,
    logging_steps=10,
    save_strategy="epoch",
    fp16=True,
    learning_rate=2e-4,
)

trainer = Trainer(model=model, args=training_args, train_dataset=tokenized_dataset)
trainer.train()

# === 3. MERGE LoRA INTO BASE MODEL ===
print("Merging LoRA weights into full model...")

merged = model.merge_and_unload()
merged.save_pretrained(merged_dir)
tokenizer.save_pretrained(merged_dir)

# === 4. CONVERT TO GGUF ===
print("Converting to GGUF for Ollama...")

os.makedirs(gguf_path, exist_ok=True)
cmd = [
    "python3", "convert.py",
    "--outfile", f"{gguf_path}/bible-llama3.gguf",
    "--model-type", "llama",
    "--model-path", merged_dir,
]
subprocess.run(cmd)

# === 5. CREATE OLLAMA MODEFILE ===
modelfile = f"""\
FROM ./gguf/bible-llama3.gguf
PARAMETER temperature 0.7
SYSTEM You are a scholarly assistant fluent in Polish, Latin, and Koine Greek. You provide verse-level responses from biblical sources in their respective languages.
"""

with open(f"{output_dir}/Modelfile", "w") as f:
    f.write(modelfile)

print("\n✅ All done!")
print(f"Run your model with:\n  ollama create bible-l3 -f {output_dir}/Modelfile\n  ollama run bible-l3")
