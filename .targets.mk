TARGETS_DRAFTS := draft-wang-mmusic-encrypted-ice-candidates
TARGETS_TAGS := 
draft-wang-mmusic-encrypted-ice-candidates-00.md: draft-wang-mmusic-encrypted-ice-candidates.md
	sed -e 's/draft-wang-mmusic-encrypted-ice-candidates-latest/draft-wang-mmusic-encrypted-ice-candidates-00/g' -e 's/draft-wang-mmusic-encrypted-ice-candidates-latest/draft-wang-mmusic-encrypted-ice-candidates-00/g' $< >$@
