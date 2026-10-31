function highlight(source, palette, parser, asRanges) {
    return parser.highlight(source, palette, parser.LegacyNbt, asRanges)
}
