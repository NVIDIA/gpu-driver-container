# Normalize RPM license operands for lookup only; keep the original header in the TPN.
function canonical(s) {
    s=tolower(s); gsub(/^[ \t()]+|[ \t()]+$/,"",s)
    if(s ~ /^(l|a)?gplv[123]/) {
        sub(/v/,"-",s)
        if(s !~ /\./) sub(/[123]/,"&.0",s)
        if(s ~ /\+$/) sub(/\+$/,"-or-later",s); else s=s "-only"
    }
    if(s=="gpl+") s="gpl-1.0-or-later"
    if(s=="artistic 2.0") s="artistic-2.0"
    if(s=="asl 2.0") s="apache-2.0"
    if(s=="mplv2.0") s="mpl-2.0"
    if(s=="artistic") s="artistic-1.0"
    return s
}
{ line=$0; gsub(/[ \t]+([Aa][Nn][Dd]|[Oo][Rr])[ \t]+/,"\n",line)
  n=split(line,a,"\n"); for(i=1;i<=n;i++) {s=canonical(a[i]); if(!seen[s]++) print s} }
