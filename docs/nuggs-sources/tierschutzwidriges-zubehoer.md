# *Tierschutzwidriges Zubehör* — NUGGS source record

## Source

- **Publisher:** Deutscher Tierschutzbund e.V.
- **Title:** *Tierschutzwidriges Zubehör*
- **Edition shown by the publisher:** June 2024
- **Primary document:** [publisher PDF](https://www.tierschutzbund.de/fileadmin/Seiten/tierschutzbund.de/Downloads/Berichte/Positionspapier_DTSchB_Tierschutzwidriges_Zubehoer.pdf)
- **NUGGS issue:** [#82](https://github.com/shaiss/print-bench/issues/82)
- **Local source pointer:** [`tierschutzwidriges-zubehoer.source.url`](tierschutzwidriges-zubehoer.source.url)

This record and its companion decision map belong to the NUGGS system. They
are kept together so the product charter can cite a stable repository path
instead of relying on an external URL alone.

## Retrieval status

The publisher PDF could not be downloaded in the 2026-08-04 task environment:
DNS lookup failed through both the repository runner and the document-fetch
tool, and a direct connection to the independently resolved address timed
out. No PDF attachment was present in the issue or task session. Consequently,
this file is **not a full Markdown transcription**, and the source PDF is not
vendored here. Replacing this record with a page-faithful conversion remains
required when the supplied binary is available.

The passage below was returned by web search as indexed text from the primary
PDF. It is recorded as an excerpt, not represented as an end-to-end reading.

## Indexed primary-text excerpt

> Kunststoffröhren sind nur dann akzeptabel, wenn sie höchstens die doppelte
> Körperlänge des Tieres haben, eine ausreichende Belüftung gewährleisten und
> mit einer Gebrauchsanleitung versehen sind, die deutlich macht, dass
> derartige Röhren nicht missbräuchlich verwendet …

The search index truncated the sentence after `verwendet`; the omitted ending
must be checked against the PDF before restoring it.

### Working translation

> Plastic tubes are acceptable only if they are at most twice the animal's
> body length, ensure adequate ventilation, and are supplied with instructions
> that make clear that such tubes must not be misused …

This translation is explanatory and is not a substitute for the German source.

## NUGGS interpretation

### Scope

The indexed sentence grammatically applies its three predicates to
`Kunststoffröhren` (plastic tubes):

1. they are at most twice the animal's body length;
2. they ensure adequate ventilation; and
3. they come with instructions against misuse.

That wording supports a **per-tube** criterion rather than an explicit sum
across an assembled system. It also confirms that length, ventilation, and
instructions are conjunctive conditions.

It does **not**, by itself, define NUGGS's engineering concept of a continuous
`RUN`, say that a coupling resets the length, or explain how connected tubes
are aggregated. The per-run mapping remains a NUGGS interpretation until the
paragraph and surrounding definitions can be checked in the complete PDF.

### Product-manager decision

- Keep N2's `2 × body length` number.
- Treat the source as supporting per-tube scope, but retain N2's provisional
  marker until the complete PDF is read.
- Do not present NUGGS's definitions of a run or break as source language.
- Keep the ventilation requirement attached whenever the length criterion is
  cited.
- Keep branched and looping layouts publication-blocked until full-text review.

## Still unverified

- The complete paragraph, section heading, page number, and surrounding
  definitions.
- Whether another passage discusses the total length of connected systems.
- Whether the document contains the 7 cm entrance-opening criterion.
- Whether the 7 cm figure concerns entrances, tube bores, or both.
- Any document-wide qualification or exception affecting the excerpt.

## Companion reference

[`tierschutzwidriges-zubehoer-decision-map.svg`](tierschutzwidriges-zubehoer-decision-map.svg)
is a vector decision map for quick charter review. Its status labels are part
of the evidence: green means supported by the indexed source sentence, amber
means NUGGS interpretation, and red means blocked pending the complete PDF.

