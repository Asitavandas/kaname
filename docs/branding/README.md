# ΛuthWire approved artwork

Approved by the operator on 22 October 2026. The display name starts with the
Greek capital Lambda (U+039B); technical AuthWire filenames and identifiers retain
their existing spelling.

- `authwire-gold-anthracite-42.svg` is the exact approved master, including the
  outlined wordmark. Its SHA-256 is
  `90639e21a88e2cfe065574121019369aeb27d49b8b6a14908b173287be1f402d`.
- `geometry-verification.json` records five separated blades: four adjacent axis
  included angles of 42 degrees, four equal horizontal cap gaps of 28 SVG units,
  and perpendicular blade widths of 36 SVG units. Geometry is exported to nine
  decimal places.
- `authwire-emblem.svg` retains exactly the master's five polygon points and
  gradients. Only the outer viewBox is cropped around the emblem, with eight
  SVG units of padding. The wordmark is removed for compact panel placement.
- `kaname/static/authwire-logo.png` is the 1200 by 742 transparent raster rendering
  of that emblem, using Sharp with proportional width resizing. The existing PNG
  route and favicon URL remain available. CSS uses `object-fit:contain`.
- The sidebar wordmark in `index.html` uses the master's glyph paths and gold
  gradient. It needs no font download and contains an accessible ΛuthWire title.

Brand colors are gold `#C6A15B` and anthracite `#25272B`, with the approved gradient
stops retained. This changes the logo, not the panel's cream/navy/sky/terracotta
color roles. No service, CA, RADIUS, policy, enrollment or GPO behavior is changed.

To render the emblem with an existing Sharp installation:

```js
await sharp('docs/branding/authwire-emblem.svg')
  .resize({width:1200}).png().toFile('kaname/static/authwire-logo.png');
```
