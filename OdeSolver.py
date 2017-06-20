#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Jun 19 10:32:49 2017

@author: zdiamond zhaoqi wang
"""
#Solves scalar and vector 1st order ODEs by Forward Euler's Method. 
import matplotlib.pyplot as plt
import numpy as np


class OdeSolver(object):
    
    def __init__(self,f, dt = 1,p = 1):
        if not callable(f):
            raise TypeError('Not sufficient')
        self.f = lambda u, p: np.asarray(f(u,p))
        self.dt = dt # default to be 1
        self.p = p
    def solve(self,u):
        self.u = u
        u_new = np.zeros((u.size)) #Vector        
        u_new = u + self.dt * self.f(self.u,self.p)
        return u_new
        
#    def solve(self,time_points):
#        self.t = np.asarray(time_points)
#        n = self.t.size
#        if self.neq == 1: #Scalar
#            self.u = np.zeros(n)
#        else:
#            self.u = np.zeros((n,self.neq)) #Vector
#        
#        self.u[0] = self.U0
#        
#        for k in range (n-1):
#            self.k = k
#            self.u[k+1] = self.advance()
#        return self.u, self.t
#    
#    def advance(self):
#        u, f, k, t = self.u, self.f, self.k, self.t
#        dt = t[k+1]-t[k]
#        u_new = u[k] + dt*f(u[k],t[k])
#        return u_new
    
#def f1(x,y):
#    return x*y+1
#func = OdeSolver(f1,dt = 0.1)
#u = func.solve(np.array([2,3,4]))
#print(u,type(u))