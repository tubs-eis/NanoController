#!/bin/python3
## Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
##                    TU Braunschweig, Germany
##                    www.tu-braunschweig.de/en/eis
##
## Use of this source code is governed by an MIT-style
## license that can be found in the LICENSE file or at
## https://opensource.org/licenses/MIT.

import os
import sys
import tempfile
import ast
import time
import numpy as np  # use numpy due to array structure, code simplicity and performance
import csv
from itertools import chain
import config as cf

# Imports from VANAGA
sys.path.append(f'{os.path.dirname(os.path.abspath(__file__))}/../../VANAGA')
from population_nano import create_starting_population
from tournament_selection_nano import tournament_individual_selection
from crossover_nano import breed_by_crossover
from mutation_nano import randomly_mutate_population


## Hamming distance between two strings in Python
## https://stackoverflow.com/questions/54172831/hamming-distance-between-two-strings-in-python
def dstHamming(str1, str2):
  return sum(c1 != c2 for c1, c2 in zip(str1, str2))

def evalHamming(iMemCycleList, chromoKeys, individual):                 # Auxiliary Function: Evaluate accumulated Hamming distance of a list of strings
  strList = []
  for i in iMemCycleList:
    if i in chromoKeys:                                                 # Get encoding of opcode mnemonic for current individual
      i = individual[chromoKeys.index(i)]
    elif cf.fitness_remove_immediates:                                  # If immediate: Continue with next element in iMemCycleList if immediates should be removed
      continue
    strList.append(i)
  hamming = 0
  for i in range(len(strList)-1):
    hamming += dstHamming(strList[i], strList[i+1])
  return hamming

def fitness(iMemCycleList, chromoKeys, population, \
hamming_over_gen, best_fitness_metric_ISE_over_gen):                    # Auxiliary Function: Calculate fitness (accumulated Hamming distances) of currently evolved population
  hamming_results = []
  best_fitness_metric_ISE = []
  for i in range(len(population)):
    population[i] = list(population[i])
    best_fitness_metric_ISE.append(population[i])                       # Track the evaluated ISE
    hamming = evalHamming(iMemCycleList, chromoKeys, population[i])     # Get accumulated Hamming distance for individual
    hamming_results.append(hamming)                                     # Add to the result progress array
    population[i] = np.array(population[i])
  population = np.array(population)
  scores = hamming_results
  index_variable = 0                                                    # depending on desired fitness metric choose min or max values traction
  if cf.tracked_fitness == 'min_metric':
    index_variable = scores.index(min(scores))
  elif cf.tracked_fitness == 'max_metric':
    index_variable = scores.index(max(scores))
  hamming_over_gen.append(hamming_results[index_variable])
  best_fitness_metric_ISE_over_gen.append(population[index_variable])
  return scores, hamming_over_gen, best_fitness_metric_ISE_over_gen


argc = len(sys.argv)
if argc > 2:
  f = open(sys.argv[1])
  cover = sys.argv[2]
elif argc > 1:
  f = tempfile.TemporaryFile('w+')
  f.write(sys.stdin.read())
  f.seek(0)
  cover = sys.argv[1]

iMemCycleList, cLutCycleList, xtraCycleList = ast.literal_eval(f.read())
f.close()


# global tracking of Hamming distances
hamming_over_gen = []
best_fitness_metric_ISE_over_gen = []

opSet = set()
iMemCycleList = list(chain(*iMemCycleList))
for i in range(len(iMemCycleList)):
  if isinstance(iMemCycleList[i], str):                                 # Find used opcodes by mnemonic string
    opSet.add(iMemCycleList[i])
  else:                                                                 # otherwise convert integer immediate to string for Hamming calculation
    iMemCycleList[i] = f'{iMemCycleList[i]:0{cf.bitlength}b}'
chromoKeys = list(opSet)                                                # Build up chromosome keys and length
chromoLen = len(chromoKeys)
population = create_starting_population(cf.population_size, chromoLen)  # VANAGA: Initialize starting population
population = list(population)                                           # Transform population and scores to use append

scores, hamming_over_gen, best_fitness_metric_ISE_over_gen = fitness(iMemCycleList, chromoKeys, population, \
hamming_over_gen, best_fitness_metric_ISE_over_gen)                     # Evaluate fitness of initial population

for generation in range(cf.maximum_generation):                         # Generation Evaluation Loop
  if cf.debugStdErr:
    print(f'{time.strftime("%Y-%m-%d %H:%M:%S")} - Gen {generation} - HD {hamming_over_gen[-1]}', file=sys.stderr)
  population = list(population)                                         # convert numpy arrays to list to use append and pop, later it will be converted backwards
  scores = list(scores)
  new_population = []                                                   # Create an empty list for the new population
  new_population = list(new_population)
  individual_best_score = 0                                             # Choose an arbitrary number of best individuals for new population
  index_best_score = 0
  for best_individual in range(cf.best_individuals_number):
    if cf.tracked_fitness == 'min_metric':
      individual_best_score = population[scores.index(min(scores))]
      index_best_score = scores.index(min(scores))
    elif cf.tracked_fitness == 'max_metric':
      individual_best_score = population[scores.index(max(scores))]
      index_best_score = scores.index(max(scores))
    new_population.append(individual_best_score)                        # Add to the new population the individual with the best fitness
    population.pop(index_best_score)                                    # pop the individual with best fitness from the population
    scores.pop(index_best_score)                                        # remove the value with best fitness in scores
  temp_population = np.array(population)                                # convert to numpy arrays
  scores = np.array(scores)
  for i in range(int(len(population))):                                 # VANAGA: Create new population generating one children at a time
    population = np.array(population)
    parent_1 = tournament_individual_selection(population, scores)
    parent_2 = tournament_individual_selection(population, scores)
    child_1 = breed_by_crossover(parent_1, parent_2)                    # VANAGA: Breed a new child and add it to the new population
    new_population.append(child_1)
  population = np.array(new_population)                                 # VANAGA: Apply mutation to new population
  population = randomly_mutate_population(population, chromoLen, cf.best_individuals_number)
  population = list(population)                                         # convert to list in order to use python methods not included in numpy arrays
  scores = list(scores)
  scores, hamming_over_gen, best_fitness_metric_ISE_over_gen = fitness(iMemCycleList, chromoKeys, population, \
  hamming_over_gen, best_fitness_metric_ISE_over_gen)                   # Evaluate fitness of currently evolved population
  gens = np.arange(1, generation + 2, 1)                                # Write CSVs of evolutionary process
  with open(f'openc_results_total.{cover}.{cf.tracked_fitness}.csv', mode='w') as results_total_file:
    fieldnames = ['Generation', 'HD']
    writer = csv.DictWriter(results_total_file, fieldnames=fieldnames)
    writer.writeheader()
    for i in range(len(gens)):
      writer.writerow({'Generation': gens[i], 'HD': hamming_over_gen[i]})
  with open(f'openc_ise_over_generations.{cover}.{cf.tracked_fitness}.csv', mode='w') as ise_metrics:
    fieldnames = ['Generation', 'Keys', 'Encoding']
    writer = csv.DictWriter(ise_metrics, fieldnames=fieldnames)
    writer.writeheader()
    for i in range(len(gens)):
      writer.writerow({'Generation': gens[i], 'Keys': chromoKeys, 'Encoding': best_fitness_metric_ISE_over_gen[i]})
  population = np.array(population)                                     # convert to numpy arrays
  scores = np.array(scores)

print(repr((chromoKeys, [list(i) for i in best_fitness_metric_ISE_over_gen], hamming_over_gen)))
