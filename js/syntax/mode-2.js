function highlight(source, palette, parser, asRanges) {
    return parser.highlight(source, palette, parser.ItemComponents, asRanges)
}
