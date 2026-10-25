"""Offline, license-pinned visual severity classifier experiment. No auto approval.

Images must be human-reviewed HITL_CC0 damage-instance crops from prepare_severity.
Pretrained weights must be the publisher's Apache-2.0 MobileNetV3 safetensors.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import random

import numpy as np
from PIL import Image
import torch
from torch.utils.data import Dataset, DataLoader

from app.vision.severity import LABELS, PREPROCESSING, preprocess_severity

PRETRAINED_REPO = "timm/mobilenetv3_small_100.lamb_in1k"
PRETRAINED_SHA256 = "46d2c063b18125884c48937afa4c49e18128869e52e8db96df48bf0a4d7ff697"


class ReviewedCrops(Dataset):
    def __init__(self, data: Path, split: str):
        self.rows = sorted((image, index) for index, label in enumerate(LABELS)
                           for image in (data / split / label).glob("*.png"))
        if not self.rows:
            raise ValueError("No expert-labelled severity crops in " + split)
        self.augment = split == "train"

    def __len__(self):
        return len(self.rows)

    def __getitem__(self, index):
        path, label = self.rows[index]
        with Image.open(path) as original:
            image = original.convert("RGB")
        if self.augment and random.random() < .5:
            image = image.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        return torch.from_numpy(preprocess_severity(image).copy()), label


def evaluate(model, loader, device):
    model.eval()
    confusion = np.zeros((3, 3), dtype=int)
    losses = []
    with torch.inference_mode():
        for x, y in loader:
            logits = model(x.to(device)).float()
            labels = y.to(device)
            losses.append(float(torch.nn.functional.cross_entropy(logits, labels)))
            for true, pred in zip(y.numpy(), logits.argmax(1).cpu().numpy()):
                confusion[int(true), int(pred)] += 1
    per_class = {}
    for index, label in enumerate(LABELS):
        tp = int(confusion[index, index])
        fp = int(confusion[:, index].sum() - tp)
        fn = int(confusion[index, :].sum() - tp)
        precision = tp / (tp + fp) if tp + fp else 0.
        recall = tp / (tp + fn) if tp + fn else 0.
        per_class[label] = {"precision": precision, "recall": recall,
                            "f1": 2 * precision * recall / (precision + recall) if precision + recall else 0.,
                            "support": int(confusion[index, :].sum())}
    return {"macro_f1": float(np.mean([v["f1"] for v in per_class.values()])),
            "confusion": confusion.tolist(), "per_class": per_class,
            "mean_cross_entropy": float(np.mean(losses))}


def train(args):
    import timm
    from safetensors.torch import load_file
    import onnxruntime as ort

    if args.output.exists():
        raise ValueError("Use a new output directory (no overwrite)")
    if args.epochs < 1 or args.batch < 1:
        raise ValueError("Invalid training configuration")
    if hashlib.sha256(args.pretrained.read_bytes()).hexdigest() != PRETRAINED_SHA256:
        raise ValueError("Pretrained weights not the reviewed Apache-2.0 publisher asset")
    audit = json.loads((args.data / "audit.json").read_text(encoding="utf-8"))
    if (audit.get("source_license") != "CC0-1.0" or audit.get("test_touched") is not False
            or audit.get("status") != "data_prepared_not_model_approved"):
        raise ValueError("Unreviewed severity training data")
    random.seed(args.seed)
    np.random.seed(args.seed)
    torch.manual_seed(args.seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(args.seed)
    torch.backends.cudnn.benchmark = False
    torch.set_num_threads(4)
    device = "cuda" if torch.cuda.is_available() else "cpu"

    train_data = ReviewedCrops(args.data, "train")
    val_data = ReviewedCrops(args.data, "val")
    if set(p.name for p, _ in train_data.rows) & set(p.name for p, _ in val_data.rows):
        raise ValueError("Train/validation severity crop leakage")
    counts = Counter(label for _, label in train_data.rows)
    if any(counts[i] < 30 for i in range(3)):
        raise ValueError("Insufficient expert-reviewed training support")
    train_loader = DataLoader(train_data, batch_size=args.batch, shuffle=True, num_workers=0)
    val_loader = DataLoader(val_data, batch_size=args.batch, shuffle=False, num_workers=0)
    model = timm.create_model("mobilenetv3_small_100", pretrained=False, num_classes=1000)
    model.load_state_dict(load_file(str(args.pretrained), device="cpu"), strict=True)
    model.reset_classifier(3)
    model = model.to(device)
    optimizer = torch.optim.AdamW(model.parameters(), lr=args.lr, weight_decay=1e-4)
    class_weights = torch.tensor([1. / np.sqrt(counts[i]) for i in range(3)], dtype=torch.float32, device=device)
    class_weights /= class_weights.mean()
    best, best_epoch, no_gain = -1., -1, 0
    args.output.mkdir(parents=True)
    logs = []
    for epoch in range(args.epochs):
        model.train()
        train_losses = []
        for x, y in train_loader:
            optimizer.zero_grad(set_to_none=True)
            logits = model(x.to(device))
            loss = torch.nn.functional.cross_entropy(logits, y.to(device), weight=class_weights)
            if not torch.isfinite(loss):
                raise RuntimeError("Nonfinite severity training loss")
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 1.)
            optimizer.step()
            train_losses.append(float(loss.detach()))
        metrics = evaluate(model, val_loader, device)
        logs.append({"epoch": epoch + 1, "train_loss": float(np.mean(train_losses)), "validation": metrics})
        if metrics["macro_f1"] > best:
            best, best_epoch, no_gain = metrics["macro_f1"], epoch + 1, 0
            torch.save(model.state_dict(), args.output / "best_state.pth")
        else:
            no_gain += 1
        if no_gain >= args.patience:
            break
    model.load_state_dict(torch.load(args.output / "best_state.pth", map_location=device, weights_only=True))
    model = model.cpu().eval()
    onnx_path = args.output / "severity.onnx"
    sample = torch.zeros((1, 3, 224, 224))
    torch.onnx.export(model, sample, str(onnx_path), input_names=["images"], output_names=["logits"],
                      opset_version=17, dynamo=False)
    options = ort.SessionOptions()
    options.intra_op_num_threads = 2
    session = ort.InferenceSession(str(onnx_path), sess_options=options, providers=["CPUExecutionProvider"])
    with torch.inference_mode():
        expected = model(sample).numpy()
    actual = session.run(["logits"], {"images": sample.numpy()})[0]
    np.testing.assert_allclose(expected, actual, atol=1e-4, rtol=1e-4)
    evidence = {"model": PRETRAINED_REPO, "pretrained_sha256": PRETRAINED_SHA256,
                "pretrained_license": "Apache-2.0", "data_audit": audit,
                "best_epoch": best_epoch, "best_macro_f1_validation": best,
                "runs": logs, "training_seed": args.seed,
                "production_approved": False, "independent_blind_test_passed": False}
    (args.output / "experiment.json").write_text(json.dumps(evidence, indent=2), encoding="utf-8")
    manifest_fragment = {"enabled": False, "approved": False, "validation_calibrated": False,
                         "labels": list(LABELS), "input_size": 224, "preprocessing": PREPROCESSING,
                         "label_source": "HITL_CC0_EXPERT_REVIEWED",
                         "model_version": "severity-experimental-v1", "threshold": .8,
                         "sha256": hashlib.sha256(onnx_path.read_bytes()).hexdigest()}
    (args.output / "severity-manifest-DRAFT.json").write_text(json.dumps(manifest_fragment, indent=2), encoding="utf-8")
    print(json.dumps({"best_validation_macro_f1": best, "model_bundle_approved": False}))


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--data", type=Path, required=True)
    p.add_argument("--pretrained", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--epochs", type=int, default=35)
    p.add_argument("--batch", type=int, default=16)
    p.add_argument("--lr", type=float, default=3e-4)
    p.add_argument("--patience", type=int, default=7)
    p.add_argument("--seed", type=int, default=2026)
    train(p.parse_args())


if __name__ == "__main__":
    main()
