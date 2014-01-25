package com.github.ixlibs.macro.aopx

import org.eclipse.xtend.lib.macro.TransformationContext
import org.eclipse.xtend.lib.macro.declaration.MutableClassDeclaration
import org.eclipse.xtend.lib.macro.declaration.MutableMethodDeclaration
import org.eclipse.xtend.lib.macro.declaration.MutableParameterDeclaration
import org.eclipse.xtend.lib.macro.declaration.TypeReference
import org.eclipse.xtext.xbase.lib.Pair

abstract class MethodTransformer {
	
	def String name() 
	
	protected extension TransformationContext context;
	
	
	def void init(TransformationContext context) {
		this.context = context
	}
	
	def void startClassTransformation(MutableClassDeclaration cls) {
		
	}
	
	def Iterable<Pair<String, TypeReference>> transformParameters(Iterable<? extends MutableParameterDeclaration> parameters) {
		parameters.map[it.simpleName -> it.type]
	}
	
	/**
	 * Format parameters to string
	 */
	def formatParameters(MutableMethodDeclaration method) {
		val s = new StringBuilder
		for (param : method.parameters) {
			if (s.length>0) { s.append(',') }
			s.append(param.simpleName)
		}
		return s.toString
	}
	
	def methodCall(MutableMethodDeclaration method, String methodName) {
		"this." + methodName + "(" + formatParameters(method) + ")"
	}
	
	def methodCallAndReturn(MutableMethodDeclaration method, String methodName) {
		if (method.returnType.void) {
			methodCall(method, methodName) + ";"
		} else {
			"return "+ methodCall(method, methodName) + ";"
		}
	}
	
	def void createForwardingCall(MutableMethodDeclaration originalDeclaration, MutableMethodDeclaration method, MutableMethodDeclaration destinationMethod)
	
} 
