# Susan Khanal - Homelab Blog

Personal tech blog at **[blogs.susankhanal.com](https://blogs.susankhanal.com)**.

Documenting homelab experiments, networking setups, and IT learning with practical notes and screenshots.

## Stack

| Layer | Tool |
|---|---|
| Static site generator | [Hugo Extended](https://gohugo.io/) |
| Theme | [Terminal by panr](https://github.com/panr/hugo-theme-terminal) |
| Hosting | [Cloudflare Pages](https://pages.cloudflare.com/) |
| Writing workflow | Obsidian + PowerShell + Python |

## Local Development

Prerequisites: Hugo Extended, Git, Python 3, VS Code.

```powershell
git clone --recurse-submodules https://github.com/susan-labs/susankhanal-blog.git
cd susankhanal-blog
hugo server -D
```

## Content Workflow

1. Create/edit posts in Obsidian.
2. Run `updateblog.ps1` to sync posts, process images, build, and push.
3. Cloudflare Pages deploys from `main` automatically.

### First test without publishing

```powershell
.\updateblog.ps1 -SkipCommit -SkipPush
```

## Useful Scripts

- `scripts/New-BlogPost.ps1`: Scaffold a new post folder and `index.md`.
- `scripts/Add-Screenshots.ps1`: Copy and rename recent screenshots into a post bundle.
- `scripts/Publish-Blog.ps1`: Validate build, commit, and push.
- `images.py`: Convert Obsidian image wikilinks to Hugo markdown image links.

## Notes

- `public/` is generated build output and should not be committed.
- Keep theme submodules initialized when cloning.
