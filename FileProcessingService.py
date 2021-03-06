import re
import os
import random
import csv
import numpy
from SupportedFileTypes import SupportedFileTypes
from SupportedDistributions import SupportedDistributions
from Utilities.OperatingSystemUtil import OperatingSystemUtil
from Utilities.SafeCastUtil import SafeCastUtil
import collections


class FileProcessingService(object):

    GENERATED_FOLDER_NAME = "/GenomeFiles"
    GENOMES_FILE_NAME = "Genomes.txt"
    IDENTIFIER_REGEX = re.compile(r'\$.+?\$')
    DEFAULT_GAUSSIAN_STANDARD_DEVIATION = 0.1
    OUTPUT_FILE_NAME = "Sim0GenomesMatrix.csv"

    DEFAULT_NUM_GENOMES = 10

    num_generated_coefficients = 0

    def __init__(self, data_file, file_type, number_of_genomes, path):
        self.data_file = data_file
        self.file_type = file_type
        self.number_of_genomes = SafeCastUtil.safeCast(number_of_genomes, int, self.DEFAULT_NUM_GENOMES)
        self.path = path

    def createGenomes(self):
        if self.file_type == SupportedFileTypes.MATLAB or self.file_type == SupportedFileTypes.OCTAVE:
            return self.handleFile("%")
        elif self.file_type == SupportedFileTypes.R:
            return self.handleFile("#")
            # Note - fn will need to be able to take in files containing booleans

    def handleFile(self, comment_character, file_name_root="genome"):
        genomes_file_list = []

        path = self.maybeCreateNewFileDirectory()

        genomes = collections.OrderedDict()
        for genome in range(1, self.number_of_genomes + 1):
            genome_name = file_name_root + str(genome) #Note - changed this to a parameter for SIM1
            coefficient_map = collections.OrderedDict()
            new_genome_file = open(path + "/" + genome_name + "." + self.file_type, "w")
            genomes_file_list.append(genome_name + "." + self.file_type)

            for line in self.data_file:
                if line[0] == comment_character:
                    new_genome_file.write(line)
                    continue
                new_line = self.maybeGenerateNewLineAndSaveCoefficientValues(coefficient_map, line)
                new_genome_file.write(new_line)
            new_genome_file.close()

            self.data_file.seek(0)
            self.num_generated_coefficients = 0
            genomes[genome_name] = coefficient_map

        self.writeGenomesKeyFilesToDirectory(genomes, path)
        genomes_matrix = self.createGenomesMatrix(genomes)
        self.writeDataFile(genomes_matrix)
        return [genomes_file_list, genomes_matrix]

    def maybeCreateNewFileDirectory(self):
        target_directory = self.path + self.GENERATED_FOLDER_NAME
        if os.getcwd() != "/":
            if not os.path.isdir(target_directory):
                os.mkdir(target_directory)
        else:
            raise ValueError('Provided path must not be root directory.')
        return target_directory

    def maybeGenerateNewLineAndSaveCoefficientValues(self, coefficient_map, line):
        target_sequences = self.extractTargetSequences(line)
        new_line = line
        for i in range(0, len(target_sequences)):
            target_sequence = target_sequences[i]
            coefficient_name = self.extractCoefficientName(target_sequence)
            distribution = self.extractDistributionName(target_sequence)
            params = self.extractParameters(target_sequence)
            coefficient_value = self.retrieveCoefficientValueFromDistribution(distribution, params)

            # Replace $stuff$ with extracted coefficient value, write to file
            new_line = new_line.replace("$" + target_sequence + "$", str(coefficient_value), 1)
            if type(coefficient_value) is str:
                coefficient_value = self.replaceCoefValue(coefficient_value)
            coefficient_map[coefficient_name] = coefficient_value
        return new_line

    def extractTargetSequences(self, line):
        return [target_sequence.replace("$", "") for target_sequence in self.IDENTIFIER_REGEX.findall(line)]

    def extractCoefficientName(self, target_sequence):
        if "name=" in target_sequence:
            return target_sequence.split("name=")[1].strip()
        else:
            self.num_generated_coefficients += 1
            return "coefficient" + str(self.num_generated_coefficients)

    def extractDistributionName(self, target_sequence):
        distribution_name = ''
        if "name=" in target_sequence or ("(" in target_sequence and ")" in target_sequence):
            distribution_name = re.findall(r'[a-z]*', target_sequence.split("name=")[0])[0]

        elif "name=" not in target_sequence and ("(" in target_sequence and ")" in target_sequence):
            distribution_name = re.findall(r'[a-z]*', target_sequence)[0]

        if distribution_name == '':
            return SupportedDistributions.GAUSS
        else:
            return distribution_name

    def extractParameters(self, target_sequence):
        pattern = re.compile('-? *\.?[0-9]+\.?[0-9]*(?:[Ee] *-? *[0-9]+)?')  # now supports scientific notation
        return [param.strip() for param in re.findall(pattern, target_sequence.split("name=")[0])]

    def retrieveCoefficientValueFromDistribution(self, distribution, params):
        # Selection from a series of both discrete and continuous probability distributions
        if distribution == SupportedDistributions.UNIFORM:
            return self.generateRandomValueFromUniformDistribution(params[0], params[1])
        elif distribution == SupportedDistributions.GAUSS:  # changed form GAUSSIAN TO GAUSS
            if len(params) <= 1:
                return self.generateRandomValueFromGaussianDistribution(params[0],
                                                                        self.DEFAULT_GAUSSIAN_STANDARD_DEVIATION * float(params[0]))
            else:
                return self.generateRandomValueFromGaussianDistribution(params[0], params[1])
        elif distribution == SupportedDistributions.DISCRETE:
            return self.generateRandomValueFromDiscreteDistribution(params)
        elif distribution == SupportedDistributions.GAMMA:
            return self.generateRandomValueFromGammaDistribution(params[0], params[1])
        elif distribution == SupportedDistributions.LOGNORMAL:
            return self.generateRandomValueFromLogNormalDistribution(params[0], params[1])
        elif distribution == SupportedDistributions.BINOMIAL:
            return self.generateRandomValueFromBinomialDistribution(params[0], params[1])
        elif distribution == SupportedDistributions.POISSON:
            return self.generateRandomValueFromPoissonDistribution(params[0])
        elif distribution == SupportedDistributions.BOOLEAN:
            return self.pickBoolean(params[0])
        else:
            raise ValueError('Unsupported distribution: ' + distribution)

    def generateRandomValueFromUniformDistribution(self, mini, maxi):
        return random.uniform(SafeCastUtil.safeCast(mini, float, -1), SafeCastUtil.safeCast(maxi, float, 1))

    def generateRandomValueFromGaussianDistribution(self, mu, sigma):
        return random.gauss(SafeCastUtil.safeCast(mu, float, 0), SafeCastUtil.safeCast(sigma, float, 1))

    def generateRandomValueFromDiscreteDistribution(self, values):
        return SafeCastUtil.safeCast(random.choice(values), float, 0)

    def generateRandomValueFromGammaDistribution(self, k, theta):
        return random.gammavariate(SafeCastUtil.safeCast(k, float, 1), SafeCastUtil.safeCast(theta, float, 1))

    def generateRandomValueFromLogNormalDistribution(self, mu, sigma):
        return random.lognormvariate(SafeCastUtil.safeCast(mu, float, 0), SafeCastUtil.safeCast(sigma, float, 1))

    def generateRandomValueFromBinomialDistribution(self, n, p):
        return numpy.random.binomial(SafeCastUtil.safeCast(n, int, 100), SafeCastUtil.safeCast(p, float, 0.5))

    def generateRandomValueFromPoissonDistribution(self, k):
        return numpy.random.poisson(SafeCastUtil.safeCast(k, int, 1))

    def pickBoolean(self, probability_of_zero):
        val = random.uniform(0, 1)
        if val < SafeCastUtil.safeCast(probability_of_zero, float, 0.6):
            return 0
        else:
            return 1

    def writeGenomesKeyFilesToDirectory(self, genomes, path):
        for genome in genomes.keys():
            key_file_extension = self.file_type
            if key_file_extension == SupportedFileTypes.OCTAVE:
                key_file_extension = SupportedFileTypes.MATLAB
            new_genome_file = open(path + "/" + genome + "_key." + key_file_extension, "w")
            for value in genomes[genome].keys():
                if self.file_type == SupportedFileTypes.MATLAB or SupportedFileTypes.OCTAVE:
                    new_genome_file.write(str(value) + "=" + str(genomes[genome][value]) + ";" + "\n")
                elif self.file_type == SupportedFileTypes.R:
                    new_genome_file.write(str(value) + "<-" + str(genomes[genome][value]) + "\n")
            new_genome_file.close()

    def createGenomesMatrix(self, genomes):
        genomes_matrix = []
        counter = 0
        for genome in genomes.keys():
            genomes_matrix.append([])
            for value in genomes[genome].keys():
                genomes_matrix[counter].append((genomes[genome][value]))
            counter = counter + 1
        return genomes_matrix

    def replaceCoefValue(self, coefficient_string):
        if coefficient_string == "":
            return int(-1)
        else:
            pos = coefficient_string.index(")")
            return int(coefficient_string[pos - 1])

    def writeDataFile(self, genomes_matrix):
        current_directory = os.getcwd()
        OperatingSystemUtil.changeWorkingDirectory(self.path + "/GenomeFiles")
        with open(self.OUTPUT_FILE_NAME, 'w') as csv_file:
            try:
                data_writer = csv.writer(csv_file)
                for i in range(0, self.number_of_genomes):
                    data_writer.writerow(genomes_matrix[i])
            finally:
                csv_file.close()
                OperatingSystemUtil.changeWorkingDirectory(current_directory)
