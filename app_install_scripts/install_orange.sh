# make sure there is no old venv
rm -rf .venv venv_orange
uv venv venv_orange --python 3.12

# activate venv because uv does not have an arg to override the .venv default path to run commands in
# (but this will still use pip inside the venv, even it the regular pip may not be available with python)
source venv_orange/bin/activate
uv pip install PyQt5
uv pip install orange3==3.39.0

# test run
uv run python3 -m Orange.canvas
