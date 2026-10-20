# Verse-art Images API

Configure `YouVersionPlatformConfiguration` with your app key before calling these APIs.
The API returns metadata; download the artwork separately from `imageURL`.

```swift
let page = try await YouVersionAPI.Images.images(
    passageID: "JHN.3.16",
    languageRanges: ["en", "es"],
    pageSize: 25,
    isBetaAPIEnabled: true
)

if let first = page.images.first {
    let image = try await YouVersionAPI.Images.image(id: first.id, isBetaAPIEnabled: true)
    print(image.passageID, image.attribution, image.imageURL)
}

if let token = page.nextPageToken {
    let nextPage = try await YouVersionAPI.Images.images(
        passageID: "JHN.3.16",
        languageRanges: ["en", "es"],
        pageSize: 25,
        pageToken: token,
        isBetaAPIEnabled: true
    )
    print(nextPage.images.count)
}
```

`isBetaAPIEnabled: true` selects `/v1-beta`; the default is the production `/v1` route.
Use the same route and filters on every page. Image IDs and continuation tokens are opaque;
pass them unchanged. Language ranges retain their order and are sent as repeated
`language_ranges[]` parameters. Omit filters to browse all images. `pageSize` must be
between 1 and 99; omitting it uses the server default of 25.

Passages must identify a single verse or verse range. Bare chapters such as `JHN.3`
are rejected by the server. A filter with no matches returns an empty `images` array.
`totalSize` can be `nil`, particularly when no passage filter is supplied.

Each image includes its ID, CDN URL, passage ID, attribution, language tag, native width
and height, and aspect ratio. Preserve the CDN URL's existing query parameters, including
any `app_key`. To select a `thumb`, `card`, or `full` rendition, set the `size` query item
on that CDN URL using `URLComponents`; `size` is not an Images API filter.
Display the returned attribution with the artwork.

The APIs use the SDK's existing authentication and error handling. Invalid page sizes,
language ranges, or empty detail IDs throw `YouVersionAPIRequestError` with
`.invalidParameter`; unauthorized requests throw `YouVersionAPIError.notPermitted`.
Malformed metadata throws a decoding error.

Contract: [YPE-6182](https://lifechurch.atlassian.net/browse/YPE-6182).
