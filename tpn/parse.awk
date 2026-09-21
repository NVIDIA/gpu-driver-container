# POSIX awk: extract declarations, conservative prose matches, and copyright statements.
# prefix selects output files; mode=detect prints only detected license names.
function trim(s) { sub(/^[ \t\r]+/, "", s); sub(/[ \t\r]+$/, "", s); return s }
function add(s) { s=trim(s); if (s!="" && !seen[s]++) names[++nn]=s }
function declared(s, a,n,i) {
    n=split(s,a,/[ \t]+(and|or)[ \t]+|,[ \t]*/)
    for(i=1;i<=n;i++) add(a[i])
}
# A wrapped synopsis must still be an expression, never the following license prose.
function synopsis(s, a,n,j) {
    sub(/^(and|or) /,"",s)
    n=split(s,a,/[ \t]+(and|or)[ \t]+|,[ \t]*/)
    for(j=1;j<=n;j++) {
        gsub(/[()]/,"",a[j]); sub(/ with .+ exception$/,"",a[j])
        if(trim(a[j]) !~ /^[A-Za-z0-9.+_-]+$/) return 0
    }
    return n>0
}
function holder(s) { s=trim(s); if(s!="" && s!="." && !holders[s]++) print s > (prefix ".holders") }
function paragraph(s, l) {
    l=tolower(s)
    # Whole statements retain wrapped names, years, and yearless ownership clauses.
    if(l ~ /(copyright|\(c\)|©)[ (c)©:]*[12][0-9][0-9][0-9]/ ||
       l ~ /copyrights?.*(are owned by|is owned by|is held by|belongs to)/ ||
       l ~ /copyright(ed)? by [a-z]/ ||
       (s ~ /(^|[ *])Copyright[ :]+(\([Cc]\) )?[A-Z][a-z]/ && l !~ /copyright[ :]+(notice|holders?|license|laws?)( |$)/)) holder(s)
}
function detect(s, t, tail,k,n,a,v,plus,after) {
    t=tolower(s); gsub(/gplv/,"gpl-",t)
    # Full GNU titles and explicit abbreviations; version is taken only from nearby text.
    while(match(t, /gnu (lesser |library |affero |free documentation |general )?(general )?public license|gnu free documentation license|(^|[^a-z])(agpl|lgpl|gpl|gfdl)([^a-z]|$)/)) {
        k=substr(t,RSTART,RLENGTH); after=substr(t,RSTART+RLENGTH); tail=substr(after,1,180)
        if(k ~ /lesser|library|lgpl/) k="LGPL"
        else if(k ~ /affero|agpl/) k="AGPL"
        else if(k ~ /documentation|gfdl/) k="GFDL"
        else k="GPL"
        # Do not attach another license's version or "later" qualification.
        if(match(tail,/gnu (lesser |library |affero |general |free documentation )|(^|[^a-z])(agpl|lgpl|gpl|gfdl)([^a-z]|$)/)) tail=substr(tail,1,RSTART-1)
        v=""; plus=""
        if(match(tail,/^[ -]*[123](\.[0-9])?([^0-9]|$)/)) v=substr(tail,RSTART,RLENGTH)
        else if(match(tail,/(version|v)[ \t]*[123](\.[0-9])?([^0-9]|$)/)) v=substr(tail,RSTART,RLENGTH)
        if(v!="") {
            sub(/^[^0-9]*/,"",v); sub(/[^0-9.]+$/,"",v); sub(/\.$/,"",v)
            if(k ~ /^(A?GPL|LGPL)$/) sub(/\.0$/,"",v)
            if(tail ~ /\+|or[ ,()a-z]*later|any later version/) plus="+"
            add(k "-" v plus)
        } else add(k)
        t=after
    }
    if(tolower(s) ~ /permission is hereby granted, free of charge/) add("MIT")
    if(tolower(s) ~ /permission to use, copy, modify/) add("MIT-style")
    if(tolower(s) ~ /redistribution and use in source and binary forms|[0-9]-clause bsd/) add("BSD")
    if(tolower(s) ~ /apache license/) {
        if(tolower(s) ~ /apache license,? (version )?2\.0/) add("Apache-2.0"); else add("Apache")
    }
    if(tolower(s) ~ /mozilla public license/) add("MPL")
    if(tolower(s) ~ /artistic license/) add("Artistic")
    if(tolower(s) ~ /public domain/) add("public-domain")
    if(tolower(s) ~ /this software is provided .as.is.*origin of this software must not be misrepresented/) add("zlib")
    if(tolower(s) ~ /permission to use, copy, modify, and(\/or)? distribute.*with or without fee/) add("ISC")
    # Preserve a document's own license title, including nonstandard agreements.
    if(s ~ /^[ \t]*[Ll]icense [Ff]or [A-Z]/ && length(s)<160) add(trim(s))
}
{
    lines[NR]=$0
    if($0 ~ /^Format:.*(copyright-format|dep5|machine-readable)/) dep5=1
    # Record common-license references without interpreting prose as declarations.
    rest=$0
    while(match(rest,/\/usr\/share\/common-licenses\/[A-Za-z0-9.+-]+/)) {
        ref=substr(rest,RSTART,RLENGTH); sub(/[.,]+$/,"",ref)
        if(prefix!="" && !refs[ref]++) print ref >> (prefix ".refs")
        rest=substr(rest,RSTART+RLENGTH)
    }
}
END {
    if(prefix!="") { printf "" > (prefix ".holders"); printf "" > (prefix ".license") }
    for(i=1;i<=NR;i++) {
        line=lines[i]; clean=trim(line)
        if(dep5 && mode!="detect") {
            if(line ~ /^License:/) {
                value=line; sub(/^License:[ \t]*/,"",value)
                while(i<NR && lines[i+1] ~ /^[ \t]/) {
                    nextline=trim(lines[i+1])
                    if((value=="" && synopsis(nextline)) || (nextline ~ /^(and|or) / && synopsis(nextline)) || nextline ~ /^with .+ exception$/ || (value ~ /( and| or|,)$/ && synopsis(nextline))) {
                        value=trim(value " " nextline); i++
                    } else break
                }
                declared(value)
            }
            if(line ~ /^Copyright:/) {
                sub(/^Copyright:[ \t]*/,"",line); holder(line)
                while(i<NR && lines[i+1] ~ /^[ \t]/) holder(lines[++i])
            }
        } else {
            if(clean=="" || clean==".") { detect(para); if(prefix!="") paragraph(para); para="" }
            else para=trim(para " " clean)
            if(clean ~ /^[Ll]icense [Ff]or [A-Z]/) detect(clean)
        }
    }
    if(!dep5 || mode=="detect") { detect(para); if(prefix!="") paragraph(para) }
    # A versioned GNU name supersedes an unversioned mention of the same family.
    for(i=1;i<=nn;i++) {
        s=names[i]; redundant=0
        if(!dep5 && s ~ /^(A?GPL|LGPL|GFDL)$/) for(j=1;j<=nn;j++) if(index(names[j],s "-")==1) redundant=1
        if(!dep5 && s ~ /^(A?GPL|LGPL|GFDL)-[0-9.]+$/) {
            for(j=1;j<=nn;j++) if(names[j]==s "+") redundant=1
        }
        if(!dep5 && s ~ /^(Apache|MPL|Artistic)$/) for(j=1;j<=nn;j++) if(index(names[j],s "-")==1) redundant=1
        if(!redundant) {
            if(mode=="detect") print s
            else { printf "%s%s%s", sep,s,(dep5 ? "" : " (detected)") > (prefix ".license"); sep=", " }
        }
    }
    if(prefix!="") print "" > (prefix ".license")
}
