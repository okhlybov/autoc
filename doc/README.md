# doc — the autoc reference manual project

Crafts the documentation type set: the containers act on the abstract element
type `T` and, for the associative containers, on the abstract index type `K`.
The generator emits the interface header alone (`doc_auto.h`) — no translation
units are needed since the manual documents the declarations, not the bodies.

## Usage

```sh
python doc.py     # regenerate doc_auto.h
doxygen Doxyfile  # produce the reference manual under reference/html
```

The generated header is then processed by Doxygen into the reference manual
covering every public operation and composite type of the container family.
