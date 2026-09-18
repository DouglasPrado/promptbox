# DESIGN.md output contract

Start/end YAML frontmatter with `---`.

```yaml
version: alpha
name: <reference-design-analysis>
description: "<dense concrete summary>"
```

Use only supported/evidenced token families:

```yaml
colors:
typography:
rounded:
spacing:
components:
```

Do not put evidence metadata into normative frontmatter.

Principles:

- semantic names over page-specific names;
- compact scales over value dumps;
- repeated evidence over isolated declarations;
- component recipes reference global tokens;
- preserve meaningful alpha/wide-gamut values when normalization would lose behavior.

Canonical sections in order:

1. `## Overview`
2. `## Colors`
3. `## Typography`
4. `## Layout`
5. `## Elevation & Depth`
6. `## Shapes`
7. `## Components`
8. `## Do's and Don'ts`
9. `## Responsive Behavior`
10. `## Iteration Guide`
11. `## Known Gaps`

Overview translates Visual DNA into implementation direction and includes `Source pages:`.

Do's/Don'ts must be source-specific enough that many rules would be wrong for another design system.

The document succeeds only when a new screen can be designed coherently without copying an existing page verbatim.
