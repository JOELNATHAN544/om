# TechDocs Plugin

TechDocs renders documentation from markdown files directly inside Backstage.

## How it Works

1. Add a `docs/` folder and `mkdocs.yml` to your repository
2. Add the annotation to your `catalog-info.yaml`:
   ```yaml
   annotations:
     backstage.io/techdocs-ref: dir:.
   ```
3. Backstage automatically builds and serves the docs under the **Docs** tab

## Writing Documentation

Create markdown files inside your `docs/` folder and reference them in `mkdocs.yml`:

```yaml
nav:
  - Home: index.md
  - API Reference: api.md
```
