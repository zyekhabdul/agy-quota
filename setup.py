from setuptools import setup

setup(
    name="agy-quota",
    version="1.2.0",
    description="Antigravity Multi-Account Token & Quota Bulk Checker",
    long_description=open("README.md", encoding="utf-8").read(),
    long_description_content_type="text/markdown",
    author="Zyekh Abdul",
    author_email="zyekhabdulqadirjailani@gmail.com",
    url="https://github.com/zyekhabdul/agy-quota",
    license="MIT",
    scripts=["bin/agy-quota"],
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
