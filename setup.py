from setuptools import setup, find_packages

setup(
    name="agy-quota",
    version="1.2.1",
    description="Antigravity Multi-Account Token & Quota Bulk Checker",
    long_description=open("README.md", encoding="utf-8").read(),
    long_description_content_type="text/markdown",
    author="Zyekh Abdul",
    author_email="zyekhabdulqadirjailani@gmail.com",
    url="https://github.com/zyekhabdul/agy-quota",
    license="MIT",
    package_dir={"": "src"},
    packages=find_packages(where="src"),
    entry_points={
        "console_scripts": [
            "agy-quota=agy_quota.cli:main",
            "agy-tokens=agy_quota.cli:main",
        ],
    },
    install_requires=[
        "cryptography>=3.4",
        "rich>=10.0",
    ],
    classifiers=[
        "Programming Language :: Python :: 3",
        "License :: OSI Approved :: MIT License",
        "Operating System :: POSIX :: Linux",
        "Environment :: Console",
    ],
    python_requires=">=3.8",
)
