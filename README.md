# Ahmed's Notebook

Source for [notes.oversight.ee](https://notes.oversight.ee/), a personal technical knowledge base built with Zensical and a Material-compatible configuration.

The site focuses on practical notes, guides, and research across:

[![GitHub Pages](https://img.shields.io/badge/GitHub%20Pages-Deployed-success?style=flat-square)](https://notes.oversight.ee)
[![CI](https://img.shields.io/github/actions/workflow/status/ahmdngi/notes.oversight.ee/ci.yml?style=flat-square)](https://github.com/ahmdngi/notes.oversight.ee/actions/workflows/ci.yml)
[![Language](https://img.shields.io/badge/language-Nix-blue?style=flat-square)]()
[![Stars](https://img.shields.io/github/stars/ahmdngi/notes.oversight.ee?style=flat-square)](https://github.com/ahmdngi/notes.oversight.ee)

- Linux system administration
- Enterprise and HPC storage, including GPFS / IBM Storage Scale and BeeGFS
- Networking and infrastructure tooling
- Cybersecurity research, including maritime OSINT
- General technical references and useful tools

## Stack

- Zensical
- Custom theme overrides in [`docs/overrides`](docs/overrides)
- Custom CSS in [`docs/stylesheets/extra.css`](docs/stylesheets/extra.css)
- GitHub Actions deployment to GitHub Pages

## Project structure

- [`mkdocs.yml`](mkdocs.yml): site configuration, navigation, theme compatibility settings, and plugins
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
zensical serve
```

Build the static site:

```bash
zensical build
```

If you use Nix, a development shell is also provided in [`shell.nix`](shell.nix).

## Deployment

The site is built and deployed automatically from the `main` branch using GitHub Actions and GitHub Pages.

## Migration note

This site now uses Zensical as the documentation engine while keeping the existing `mkdocs.yml` layout and most Material-style configuration intact for compatibility. Custom overrides in [`docs/overrides`](docs/overrides) should be verified carefully when upgrading further, since template compatibility is the most likely place for follow-up fixes.
