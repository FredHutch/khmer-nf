#!/usr/bin/env python3

import pandas as pd
from pathlib import Path
import seaborn as sns
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages


class KhmerHistSummary:

    def __init__(self):

        self.read_data()
        self.plot_data()

    def read_data(self):

        self.data = pd.concat([
            pd.read_csv(
                file
            ).assign(
                label=label,
                name=file.name.replace(".hist", ""),
                fraction=lambda d: d['count'] / d['count'].sum()
            )
            for folder, label in [
                ("abundance_dist_input", "input"),
                ("abundance_dist_output", "output")
            ]
            for file in Path(folder).glob("*.hist")
        ]).reset_index(
            drop=True
        )

    def plot_data(self):

        with PdfPages("khmer.summary.pdf") as pdf:

            for sample, df in self.data.groupby("name"):

                for y in ['count', 'fraction']:

                    sns.lineplot(
                        data=df,
                        x='abundance',
                        y=y,
                        hue='label'
                    )
                    if y == "count":
                        plt.yscale('log')
                    plt.title(sample)
                    pdf.savefig(bbox_inches="tight")
                    plt.close()


if __name__ == "__main__":

    KhmerHistSummary()
    