from pathlib import Path

def get_user_filepath_input(console_statement: str) -> Path:
    print(console_statement, end="")
    file_path = Path(input())
    if not file_path.exists():
        raise Exception("Invalid path")
    return file_path

def get_output_file_path(output_filename: str) -> Path:
    project_root_file_path = get_project_root_file_path()
    return project_root_file_path / "data" / output_filename

def get_project_root_file_path() -> Path:
    return Path(__file__).parent.parent.parent

def get_stemmed_filename(file_path: Path) -> str:
    return Path(file_path.name).stem

def add_stem_to_filename(file_path: Path, stem: str) -> Path:
    return Path(Path(file_path.name).stem + "_" + stem + file_path.suffix)