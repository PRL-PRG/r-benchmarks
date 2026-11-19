# Build or clean the marker.c
R ?= R

.PHONY: marker clean

marker: marker.so

marker.so: marker.c
	$(R) CMD SHLIB marker.c -o marker.so

clean:
	rm -f marker.o marker.so
