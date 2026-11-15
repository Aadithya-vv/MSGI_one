# MSEC media approval record: pending

Reviewed 2026-11-15. **No permission to redistribute/bundle/commit the following
photographs or crest has been confirmed.** The owner explicitly confirmed this
during Task 12B and directed continued map/UI work with placeholders.

Primary provenance: [official MSEC homepage](https://msec.edu.in/) and
[official gallery](https://msec.edu.in/gallery.html). The website footer reserves
copyright; its public availability is not recorded redistribution approval.
No contact, email or approval request was sent to anyone by the agent.

| Candidate | Provenance and inspection | Proposed use after approval |
| --- | --- | --- |
| [campus.jpeg](https://msec.edu.in/assets/img/campus.jpeg) | Homepage identifies MSEC campus; gallery labels Main Campus. Visually inspected building exterior/campus view. JPEG 1599×899, 243,969 bytes. | One selective welcome/home hero, with aspect-preserving fit and readable navy-backed text. Do not place a photograph on every screen. |
| [infra2.JPG](https://msec.edu.in/assets/img/infra2.JPG) | Official gallery labels Campus Feature. Inspection shows an aerial sports-field view, **not an entrance**. JPEG 5280×3956, 16,486,400 bytes. | Optional secondary campus context only. Too large to ship unchanged; any optimized derivative needs approved reuse scope. |
| [msec-crest-transparent.png](https://msec.edu.in/assets/img/msec-crest-transparent.png) | Homepage header explicitly identifies the college crest. Original PNG 225×225, 49,117 bytes; visually inspected. | Small institutional identity beside the MSGI One brand, contained on a neutral surface, without stretching, tinting, cropping or redrawing the crest. |

This confirms official-site provenance, not independent dating/geolocation,
college endorsement of MSGI One or authorization for app/repository use. No
unrelated institution or invented photograph/crest was substituted.

Original SHA-256 values:

```text
campus.jpeg
da40a89b91d4cdd3f4ff6634e285ced61d91280e97819c44ffcc8e5a43a8e3cf
infra2.JPG
c3fe78592b23ee89b596230fba88f34bd5ca6dc7261d2cf60dba61cce8e2c1b8
msec-crest-transparent.png
75c8eb8c57fe311d75503f3d17d0f7f74b61df4493424dd161d5e069d3850345
```

Review copies are under ignored `build/task12b/reference-review/`, outside the
Flutter asset catalog. A reduced **inspection-only** thumbnail was made for the
large aerial photograph because the original exceeded preview limits; original
bytes remain unchanged. No original/thumbnail is committed or bundled. No APK
asset variants were generated or registered in pubspec.yaml.

## Approval needed before integration

An appropriate college representative with authority over branding/media must
confirm the exact files, authorizer/role, rights to offline APK distribution and
Git inclusion, permitted optimization/cropping for photographs, attribution and
brand usage conditions. Public/private repository scope should be explicit.
The authorizer is currently unknown; no approval is invented or self-assigned.

After that review: retain original checksums, prepare bounded Android resolutions
with preserved aspect ratios, measure encoded/decoded size, register only approved
local variants and test offline loading/error states at relevant device densities.
The 225px crest is adequate for a small contained mark; request approved larger
artwork if necessary instead of inventing a vector crest or upscaling it blindly.

Until then, the app uses labelled campus/logo placeholders and factual MSEC text.
The existing MSGI One name, tagline, generic product mark and native launcher icon
remain intact. Placeholders do not imply official imagery or institutional approval.
