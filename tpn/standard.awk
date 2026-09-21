# Index only complete, recognizable license documents, never infer from RPM names.
# Output a canonical text identifier. Package-specific variants remain unavailable.
{ all=all $0 "\n"; if(NR<12) title=title " " tolower($0) }
END {
    if(all ~ /END OF TERMS AND CONDITIONS/) {
        if(title ~ /gnu general public license.*version 1,/) print "gpl-1.0"
        if(title ~ /gnu general public license.*version 2,/) print "gpl-2.0"
        if(title ~ /gnu general public license.*version 3,/) print "gpl-3.0"
        if(title ~ /gnu lesser general public license.*version 2.1,/) print "lgpl-2.1"
        if(title ~ /gnu library general public license.*version 2,/) print "lgpl-2.0"
        if(title ~ /gnu lesser general public license.*version 3,/) print "lgpl-3.0"
        if(title ~ /apache license.*version 2.0,/) print "apache-2.0"
    }
    if(title ~ /mozilla public license.*version 2.0/ && all ~ /10. Versions of the License/) print "mpl-2.0"
    if(title ~ /the "artistic license"/ && all ~ /Preamble/ && all ~ /Package/) print "artistic-1.0"
    if(title ~ /artistic license 2.0/ && all ~ /Preamble/) print "artistic-2.0"
    # MIT/BSD carry the donor's notices. They are examples, not recovered package notices.
    if(all ~ /Permission is hereby granted, free of charge/ && all ~ /THE SOFTWARE IS PROVIDED/ && length(all)<4000) print "mit"
    if(all ~ /Redistribution and use in source and binary forms/ && all ~ /THIS SOFTWARE IS PROVIDED/ && length(all)<4000) print "bsd"
}
