VENV := .venv
PY   := $(VENV)/bin/python

.PHONY: test clean

test: $(VENV)
	$(PY) -m pytest -q

$(VENV):
	python3 -m venv $(VENV)
	$(PY) -m pip install -q --upgrade pip pytest

clean:
	rm -rf $(VENV) .pytest_cache tests/__pycache__ waggle/data/__pycache__
