#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Thu Jun 15 15:58:09 2017

@author: zhaoqiwang
"""

import numpy as np
from OdeSolver import *

class Node(object):
    def __init__(self,name = 'no_name',value =0, change_rate = 0):
        self.name = name
        self.value = value
        self.change_rate = change_rate
        

    def change_val(self,new_vlaue):
        self.value = new_vlaue
    
    def up_date(self):
        '''update the value of a node based on its change_rate'''
        new_value = self.value + change_rate
        if new_value >= 0:
            self.change_val(new_value)
        else:
            print('error:value can not be negative')
            return False

#class system(object):
#    def __init__(self,nodes,functions):
#        self.
#        


def steady_state(new_state,states):        
    '''check if a system is in a steady state,return the true|false and the index|None'''
#    for i in range(len(states)):
#        if states[i].any() != new_state.any():
#            return (True,i)
#        else:
#            return(False,None)
#    return new_state in states
    return False
        
        
def value_vector(nodes):
    '''take a list of nodes and return a list contain their value'''
    value = [i.value for i in nodes]
    return value

def update_state(init_state,func):
    '''given a list of intital_value, and functions, return a list of new_value'''
    new_state  = func.solve(init_state)
    
    return new_state
        
            

def simulation(nodes,func, max_num_times = 1000):
    '''take a list of nodes and functions, then update the value for 
    each node 1 times.'''
    initail_values = value_vector(nodes)
    states = [np.array(initail_values)]
    rate_changes = []
    t = 0
    while t < max_num_times :
        new_state = update_state(states[-1],func)#give the new state if not in a steady state
        print('new_state is',new_state)
        bo = steady_state(new_state,states)
        if bo:
            return states# return different things depanding on what we need later on 
        print(states)
        states.append(new_state)#add the new state to existing states
        print(states)
        t +=1
    print('no steady state has been found in',t,'times, None is returned')
    return None

def read_futions(file_name):
    file = open('file_name','r')
    #need a parsing function here
    pass        

def f(u,p):
    return p*u
def f1(x,y):
    return x*y+1

def test():
    nodes = [Node(value = 2),Node(value = 3),Node(value = 4)]
    func = OdeSolver(f1,dt = 0.1)
    results = simulation(nodes,func, max_num_times = 2)
    print(results)
    


#some example diff_q
#fuctions = 
#dx1 = k11*x1.value + k12 *(x1.value + x2.value)
#dx2 = k21*x2.value + k22 *(x1.value + x2.value)
#dx3 = k31*x3.value + k32 *(x1.value + x2.value + x3.value)
#fuctions = []
#
#food_web = []