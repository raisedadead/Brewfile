BEGIN {
    headings["Formula"] = "Formulae"
    headings["Cask"] = "Casks"
    headings["App"] = "App Store"
    headings["Tap"] = "Taps"
    headings["VSCode"] = "VS Code extensions"
    headings["Service"] = "Services to start"
}

$0 == "brew bundle can't satisfy your Brewfile's dependencies." { next }
$0 == "The Brewfile's dependencies are satisfied." { print "OK"; next }
$0 == "Satisfy missing dependencies with `brew bundle install`." { action = 1; next }

/^→ (Formula|Cask|App|Tap|Service|VSCode Extension) .+ needs to be (installed( or updated)?|started)\.$/ {
    heading = headings[$2]
    if (!(heading in entries)) {
        order[++count] = heading
    }
    entry = $0
    sub(/^→ (Formula|Cask|App|Tap|Service|VSCode Extension) /, "", entry)
    sub(/ needs to be (installed( or updated)?|started)\.$/, "", entry)
    entries[heading] = entries[heading] "  " entry "\n"
    next
}

{
    print
    printed = 1
}

END {
    for (i = 1; i <= count; i++) {
        if (printed) print ""
        heading = order[i]
        printf "%s\n%s", heading, entries[heading]
        printed = 1
    }
    if (action) {
        if (printed) print ""
        print "Run: just install-brewfile"
    }
}
