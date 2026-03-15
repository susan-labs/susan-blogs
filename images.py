import argparse
import re
import shutil
from pathlib import Path
from urllib.parse import quote


WIKILINK_PATTERN = re.compile(
    r"\[\[([^\]|]+\.((?:png|jpg|jpeg|webp)))(?:\|([^\]]+))?\]\]",
    re.IGNORECASE,
)


def sanitize_alt_text(value: str) -> str:
    base = Path(value).stem
    return re.sub(r"[-_]+", " ", base).strip() or "Image"


def process_markdown_file(file_path: Path, attachments_dir: Path, static_images_dir: Path) -> int:
    content = file_path.read_text(encoding="utf-8")
    copied = 0

    def replace_match(match: re.Match) -> str:
        nonlocal copied

        image_name = match.group(1)
        custom_alt = match.group(3)
        alt_text = (custom_alt or sanitize_alt_text(image_name)).strip()
        encoded_name = quote(image_name)
        image_source = attachments_dir / image_name

        if image_source.exists():
            destination = static_images_dir / image_name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(image_source, destination)
            copied += 1

        return f"![{alt_text}](/images/{encoded_name})"

    updated_content = WIKILINK_PATTERN.sub(replace_match, content)
    if updated_content != content:
        file_path.write_text(updated_content, encoding="utf-8")

    return copied


def main() -> None:
    script_dir = Path(__file__).resolve().parent

    parser = argparse.ArgumentParser(
        description="Convert Obsidian image wikilinks to Hugo markdown image links."
    )
    parser.add_argument(
        "--posts-dir",
        default=str(script_dir / "content" / "posts"),
        help="Path to Hugo posts directory.",
    )
    parser.add_argument(
        "--attachments-dir",
        default=r"C:\MyBlogs\MyBlogs\attachments",
        help="Path to Obsidian attachments directory.",
    )
    parser.add_argument(
        "--static-images-dir",
        default=str(script_dir / "static" / "images"),
        help="Path to Hugo static images directory.",
    )
    args = parser.parse_args()

    posts_dir = Path(args.posts_dir)
    attachments_dir = Path(args.attachments_dir)
    static_images_dir = Path(args.static_images_dir)

    if not posts_dir.exists():
        raise SystemExit(f"Posts directory not found: {posts_dir}")
    if not attachments_dir.exists():
        raise SystemExit(f"Attachments directory not found: {attachments_dir}")

    total_copied = 0
    processed_files = 0

    for markdown_file in posts_dir.rglob("*.md"):
        copied = process_markdown_file(markdown_file, attachments_dir, static_images_dir)
        total_copied += copied
        processed_files += 1

    print(
        f"Processed {processed_files} markdown files. Copied {total_copied} image file(s) to static/images."
    )


if __name__ == "__main__":
    main()
