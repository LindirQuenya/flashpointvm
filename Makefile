alpine.qcow2: setup.sh
	./build.sh alpine.qcow2

.PHONY: clean
clean:
	rm -f alpine.qcow2 snapshot.7z
