from pathlib import Path

PROJECT_NAME = "insurance-analytics"

STRUCTURE = [
    # src/sql
    "src/sql/ddl/01_create_dimensions.sql",
    "src/sql/ddl/02_create_facts.sql",
    "src/sql/ddl/03_indexes_constraints.sql",
    "src/sql/ddl/04_audit_tables.sql",

    "src/sql/etl/01_data_generation.sql",
    "src/sql/etl/02_incremental_load.sql",
    "src/sql/etl/03_scd_logic.sql",

    "src/sql/views/vw_policy.sql",
    "src/sql/views/vw_premium.sql",
    "src/sql/views/vw_claims.sql",

    "src/sql/procedures/sp_load_policies.sql",
    "src/sql/procedures/sp_load_premiums.sql",
    "src/sql/procedures/sp_load_claims.sql",

    "src/sql/validation/row_count_checks.sql",
    "src/sql/validation/reconciliation_checks.sql",
    "src/sql/validation/data_quality_checks.sql",

    # src/powerbi
    "src/powerbi/model/.gitkeep",
    "src/powerbi/dax/measures_basic.md",
    "src/powerbi/dax/measures_advanced.md",
    "src/powerbi/dax/time_intelligence.md",
    "src/powerbi/themes/.gitkeep",

    # docs
    "docs/Project_Charter.md",
    "docs/Architecture_Design.md",
    "docs/Data_Model.md",
    "docs/BRD.md",
    "docs/Functional_Spec.md",
    "docs/Design_Spec.md",
    "docs/Test_Plan.md",
    "docs/Deployment_Guide.md",
    "docs/Decisions_Log.md",

    # tests
    "tests/sql_tests.md",
    "tests/powerbi_tests.md",
    "tests/uat_signoff.md",

    # data
    "data/samples/README.md",

    # assets
    "assets/images/.gitkeep",
    "assets/diagrams/.gitkeep",
    "assets/screenshots/.gitkeep",

    # environments
    "environments/dev/config.yml",
    "environments/dev/sql.env.md",
    "environments/dev/powerbi.env.md",

    "environments/uat/config.yml",
    "environments/uat/sql.env.md",
    "environments/uat/powerbi.env.md",

    "environments/prod/config.yml",
    "environments/prod/sql.env.md",
    "environments/prod/powerbi.env.md",

    # root files
    ".gitignore",
    "README.md",
    "CHANGELOG.md",
]

GITIGNORE_CONTENT = """# Python
__pycache__/
*.pyc
.venv/
.env

# OS
.DS_Store
Thumbs.db

# Power BI
*.pbix
*.pbit
*.pbi
"""

README_CONTENT = f"""# {PROJECT_NAME}

Enterprise-grade Insurance Analytics project (DEV → UAT → PROD).
"""

CHANGELOG_CONTENT = """# Changelog
All notable changes to this project will be documented here.
"""

SAMPLE_README_CONTENT = """# Sample Data (Sample Only)
Tiny sample files only. Real data lives in SQL.
"""

def ensure_file(path: Path, content: str = ""):
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists():
        path.write_text(content, encoding="utf-8")

def main():
    root = Path(".")
    for rel in STRUCTURE:
        p = root / rel
        if p.name == ".gitkeep":
            p.parent.mkdir(parents=True, exist_ok=True)
            ensure_file(p, "")
        elif p.name == ".gitignore":
            ensure_file(p, GITIGNORE_CONTENT)
        elif p.name == "README.md":
            ensure_file(p, README_CONTENT)
        elif p.name == "CHANGELOG.md":
            ensure_file(p, CHANGELOG_CONTENT)
        elif rel == "data/samples/README.md":
            ensure_file(p, SAMPLE_README_CONTENT)
        else:
            ensure_file(p, "")

    print("✅ Project scaffold created successfully.")

if __name__ == "__main__":
    main()
