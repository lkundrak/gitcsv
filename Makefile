JGIT=$(wildcard /usr/share/eclipse/dropins/jgit/eclipse/plugins/org.eclipse.jgit_*.jar)
OPENCSV=$(shell build-classpath opencsv)

all: gitcsv.class

%.class: %.java
	javac -classpath $(JGIT):$(OPENCSV) $<

clean:
	-rm -- *.class
