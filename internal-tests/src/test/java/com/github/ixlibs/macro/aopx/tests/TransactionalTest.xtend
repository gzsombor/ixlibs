package com.github.ixlibs.macro.aopx.tests

import com.github.ixlibs.macro.aopx.Aspect
import javax.persistence.EntityManagerFactory

@Aspect(types="jpa")
class TransactionalTest {
	
	EntityManagerFactory fact;	
	
	def void doSomethingInTransact(String name, int value) {
		System.out.println("Hello "+name+" : "+value + " the manager is "  /* + manager.toString*/)
	} 
}