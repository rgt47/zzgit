# Image Sources

This directory holds the static images used by the zzgit post. The
hero slot is a terminal-mockup PNG depicting `zzgit` itself; the three
ambiance slots are shared coffee placeholders to be replaced with
post-specific imagery before publication.

## Image slots in use

| Slot | File | Referenced from `index.qmd` | Status |
|---|---|---|---|
| Hero (80%) | `zzgit-hero.jpg` | YAML `image:` and L21 | Final. Gemini-generated typewriter-with-green-terminal-output scene, resized to 1600 px wide per blog convention. |
| Ambiance 1 | `placeholder-coffee-02.jpg` | L61 (after Objectives) | Placeholder. Replace with a scene depicting the Conventional Commits wizard. |
| Ambiance 2 | `placeholder-coffee-03.jpg` | L189 (after Configuration) | Placeholder. Replace with a scene depicting the secret-scan refusal. |
| Ambiance 3 | `placeholder-coffee-04.jpg` | L297 (before Lessons Learnt) | Placeholder. Replace with a scene depicting the post-commit confirmation. |

The Gemini prompts used for the hero and suggested for the three
ambiance slots are archived in the conversation record; regenerate
from there if needed.

## Hero: processing recipe

The hero was generated via Gemini (Imagen 3) from a prompt requesting a
vintage typewriter with green terminal-style output on the paper in
the carriage. Processed per the blog's convention:

```sh
magick ~/Downloads/Gemini_Generated_Image_XXXX.png \
  -resize 1600x -strip -quality 85 \
  zzgit-hero.jpg
```

## Placeholder coffee images (shared across posts)

Inherited from template 47. Shared across multiple qblog posts until
replaced with post-specific screenshots or generated images per
`IMAGE_GENERATION_PLAN.md`.

- `placeholder-coffee-02.jpg`: Photo on Unsplash (ID: Hy4eZgKCcXI).
  Black coffee in ceramic mug near pen on open notebook. Licence:
  Unsplash Free.
- `placeholder-coffee-03.jpg`: Photo by Jojo Yuen on Unsplash
  (ID: dLkBaK_KJbw). Coffee cup, atmospheric. Licence: Unsplash Free.
- `placeholder-coffee-04.jpg`: Photo on Unsplash (ID: wiw9kVxFXnU).
  Clear glass pitcher beside coffee glass, pour-over. Licence:
  Unsplash Free.

## Licence

`zzgit-hero.jpg` was generated via Google Gemini (Imagen 3). Gemini's
terms permit use of generated images; no third-party attribution is
required but the generation source is recorded here for provenance.
The coffee placeholders are Unsplash Free-licence and require
attribution as recorded above.

## Conventions for adding images

1. Save the image to this directory: `analysis/media/images/<file>`.
2. Add an entry to the table above and, if applicable, a licence or
   source note below.
3. Reference the image in the post as
   `![Description](media/images/<file>){.img-fluid width=<n>%}`.
4. Commit the image, its text source (if regenerable), and the README
   update together.
