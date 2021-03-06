import logging
import unittest
import os

from MachineLearningDataProcessingService import MachineLearningDataProcessingService
from GraphingService import GraphingService
from SupportedAnalysisTypes import SupportedAnalysisTypes


class MachineLearningDataProcessingServiceIT(unittest.TestCase):

    log = logging.getLogger(__name__)
    log.setLevel(logging.INFO)

    def setUp(self):
        self.current_working_dir = os.getcwd()  # Should be this package.
        self.sample_output = self.current_working_dir + "/SampleDataFiles/BoolNetOutputSample.csv"
        self.sample_genomes_matrix = self.current_working_dir + "/SampleDataFiles/BoolNetGenomesMatrixSample.csv"
        self.sample_similarity_matrix = self.current_working_dir + "/SampleDataFiles/BoolNetSimilarityMatrixSample.csv"

    def tearDown(self):
        data_dir = [file for file in os.listdir(self.current_working_dir + "/SampleDataFiles")]
        if self.current_working_dir != "/" and GraphingService.DEFAULT_PLOT_FILENAME + ".png" in data_dir:
            os.remove(self.current_working_dir + "/SampleDataFiles/" + GraphingService.DEFAULT_PLOT_FILENAME + ".png")

    def testOneHotEncodingForSIM0(self):
        machine_learning_processor = MachineLearningDataProcessingService(1)
        genomes_matrix = machine_learning_processor.readCSVFile(self.sample_genomes_matrix)
        variables = [3, 6, 4, 150, -10, 4]  # Should get deduped, reverse sorted, and the out of index ones ignored.
        encoded_matrix = machine_learning_processor.oneHotEncodeCategoricalVariables(genomes_matrix, variables)
        assert len(encoded_matrix[0]) != len(genomes_matrix[0])

    def testSIM0ClassifierAnalysis(self):
        machine_learning_processor = MachineLearningDataProcessingService(1)
        machine_learning_processor.performMachineLearningOnSIM0(self.sample_output, self.sample_genomes_matrix,
                                                                SupportedAnalysisTypes.CLASSIFICATION, None)
        self.assertPlotPNGCreatedSuccessfully()

    # Need a good dataset to test this on, otherwise it takes forever SVM regression fitting.
    # def testSIM0RegressionAnalysis(self):
    #     machine_learning_processor = MachineLearningDataProcessingService(1)
    #     machine_learning_processor.performMachineLearningOnSIM0(self.sample_output, self.sample_genomes_matrix,
    #                                                             SupportedAnalysisTypes.REGRESSION)
    #     self.assertPlotPNGCreatedSuccessfully()

    def testSIM1ClassifierAnalysis(self):
        machine_learning_processor = MachineLearningDataProcessingService(1)
        machine_learning_processor.performMachineLearningOnSIM1(self.sample_output, self.sample_similarity_matrix,
                                                                SupportedAnalysisTypes.CLASSIFICATION)
        self.assertPlotPNGCreatedSuccessfully()

    def testSIM1RegressionAnalysis(self):
        machine_learning_processor = MachineLearningDataProcessingService(1)
        machine_learning_processor.performMachineLearningOnSIM1(self.sample_output, self.sample_similarity_matrix,
                                                                SupportedAnalysisTypes.REGRESSION)
        self.assertPlotPNGCreatedSuccessfully()

    def testSIM0SIM1CombinedClassifierAnalysis(self):
        machine_learning_processor = MachineLearningDataProcessingService(1)
        machine_learning_processor.performFullSIM0SIM1Analysis(self.sample_output, self.sample_genomes_matrix,
                                                               self.sample_similarity_matrix,
                                                               SupportedAnalysisTypes.CLASSIFICATION, None)
        self.assertPlotPNGCreatedSuccessfully()

    # Need a good dataset to test this on, otherwise it takes forever at SVM regression fitting.
    # def testSIM0SIM1CombinedRegressionAnalysis(self):
    #     machine_learning_processor = MachineLearningDataProcessingService(1)
    #     machine_learning_processor.performFullSIM0SIM1Analysis(self.sample_output, self.sample_genomes_matrix,
    #                                                            self.sample_similarity_matrix,
    #                                                            SupportedAnalysisTypes.REGRESSION)
    #     self.assertPlotPNGCreatedSuccessfully()

    def assertPlotPNGCreatedSuccessfully(self):
        assert len([file for file in os.listdir(self.current_working_dir + "/SampleDataFiles")
                    if file == GraphingService.DEFAULT_PLOT_FILENAME + ".png"]) == 1
