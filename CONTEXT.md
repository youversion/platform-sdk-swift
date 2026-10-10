# YouVersion Platform SDK

Swift SDK for reading and interacting with Bible text from the YouVersion Platform.

## Language

### Highlights

**Highlight**:
A user's saved color marking on a contiguous range of verses in one chapter.
_Avoid_: Mark, annotation

**Highlight color**:
The color a user chose for a Highlight, painted behind the verse text.

**Adjacent highlights**:
Highlighted text that touches other highlighted text on the same line, on the neighbouring wrapped line, or on the first line of the next paragraph or poetry line, regardless of whether the Highlights are the same color or separately saved. Adjacent highlights read as one continuous block with no unpainted space between them.
_Avoid_: Consecutive highlights, merged highlights

**Verse label**:
The verse number shown inline before a verse's text, including the spacing that separates it from the previous verse.
_Avoid_: Verse number (when referring to the rendered element)
