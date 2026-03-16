# Ahmed's Notebook

Source for [notes.ahmdngi.io](https://notes.ahmdngi.io/), a personal technical knowledge base built with MkDocs and the Material theme.

The site focuses on practical notes, guides, and research across:

- Linux system administration
- Enterprise and HPC storage, including GPFS / IBM Storage Scale and BeeGFS
- Networking and infrastructure tooling
- Cybersecurity research, including maritime OSINT
- General technical references and useful tools

## Stack

- MkDocs
- Material for MkDocs
- Custom theme overrides in [`docs/overrides`](docs/overrides)
- Custom CSS in [`docs/stylesheets/extra.css`](docs/stylesheets/extra.css)
- GitHub Actions deployment to GitHub Pages

## Project structure

- [`mkdocs.yml`](mkdocs.yml): site configuration, navigation, theme, and plugins
- [`docs/index.md`](docs/index.md): homepage content
- [`docs/content`](docs/content): main documentation pages
- [`docs/overrides`](docs/overrides): theme template overrides
- [`.github/workflows/ci.yml`](.github/workflows/ci.yml): build and deploy workflow

## Local development

Install dependencies:

```bash
pip install -r requirements.txt
```

Run the local development server:

```bash
mkdocs serve
```

Build the static site:

```bash
mkdocs build
```

If you use Nix, a development shell is also provided in [`shell.nix`](shell.nix).

## Deployment

The site is built and deployed automatically from the `main` branch using GitHub Actions and GitHub Pages.
