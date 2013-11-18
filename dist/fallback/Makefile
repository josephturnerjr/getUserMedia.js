
SWFMILL     := swfmill
MTASC       := mtasc

MTASCSTDLIB := /usr/share/mtasc/std

main:
	$(SWFMILL) -V simple src/jscam.xml jscam.swf
	$(MTASC) -v -swf jscam.swf -main jscam.as -version 8 -cp src -cp $(MTASCSTDLIB)
	$(SWFMILL) swf2xml jscam.swf | sed 's/objectID="2"/objectID="1"/g'|swfmill xml2swf stdin jscam.swf

clean:
	rm -f jscam.swf

