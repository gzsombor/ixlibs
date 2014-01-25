package com.github.ixlibs.macro.aopx

import java.lang.annotation.ElementType
import java.lang.annotation.Target
import java.util.Arrays
import java.util.Collections
import java.util.HashMap
import java.util.List
import org.eclipse.xtend.lib.macro.Active
import org.eclipse.xtend.lib.macro.RegisterGlobalsContext
import org.eclipse.xtend.lib.macro.RegisterGlobalsParticipant
import org.eclipse.xtend.lib.macro.TransformationContext
import org.eclipse.xtend.lib.macro.TransformationParticipant
import org.eclipse.xtend.lib.macro.declaration.ClassDeclaration
import org.eclipse.xtend.lib.macro.declaration.MutableClassDeclaration
import org.eclipse.xtend.lib.macro.declaration.MutableMethodDeclaration
import org.eclipse.xtend.lib.macro.declaration.NamedElement
import org.eclipse.xtend.lib.macro.declaration.Type
import org.eclipse.xtend.lib.macro.declaration.Visibility

@Target(ElementType::TYPE)
@Active(typeof(AspectProcessor))
annotation Aspect {
	String[] types	
}


class CompilerContext {
	
	extension TransformationContext transformation
	
	final package MutableClassDeclaration classDeclaration
	
	private Type aspectType
	
	val mappings = new HashMap<String, MethodTransformer> () 
	
	new(TransformationContext context, MutableClassDeclaration classDeclaration) {
		this.transformation = context
		this.classDeclaration = classDeclaration
		aspectType = findTypeGlobally(typeof(Aspect));
		
		addTransformer(new NopMethodTransformer)
		addTransformer(new LoggingMethodTransformer)
		addTransformer(new ValidatingMethodTransformer)
		addTransformer(new JPATransactionTransformer)
	}
	
	private def addTransformer(MethodTransformer tr) {
		tr.init(transformation)
		tr.startClassTransformation(classDeclaration)
		mappings.put(tr.name, tr)
	}
	
	def getAspectTypes(MutableClassDeclaration decl) {
		val annotValue = decl.findAnnotation(aspectType)
		val value = annotValue?.getValue("types")
		if (value instanceof String) {
			Collections.singletonList(value as String)
		} else if (value instanceof String[]) {
			return Arrays.asList(value as String[])
		} else {
			throw new RuntimeException("Unexpected '"+value +"' type:"+value?.class)
		}
	}

	def MethodTransformer getAspectImplementation(String name) {
		mappings.get(name)
	}
	
	def getTransformers() {
		getAspectTypes(classDeclaration)?.reverseView?.map[getAspectImplementation(it)]?.filter[ it != null]
	}
	
	def getMethods() {
		classDeclaration.declaredMethods
	}
}

class NopMethodTransformer extends MethodTransformer {
	
	override String name() {
		"nop"
	}
	
	override void createForwardingCall(MutableMethodDeclaration originalMethod, MutableMethodDeclaration currentMethod, MutableMethodDeclaration destMethod) {
		currentMethod.body = [
			if (destMethod.returnType.void) {
			''' // call «destMethod.simpleName»
			 «methodCall(destMethod, destMethod.simpleName)»;
			'''
				
			} else {
			''' // call «destMethod.simpleName»
			 return «methodCall(destMethod, destMethod.simpleName)»;
			'''
			}
		]
	}
	
} 

class AspectProcessor implements RegisterGlobalsParticipant<ClassDeclaration>, TransformationParticipant<MutableClassDeclaration> {
	
	override doRegisterGlobals(List<? extends ClassDeclaration> annotatedSourceElements, RegisterGlobalsContext context) {

	}
	
	override doTransform(List<? extends MutableClassDeclaration> annotatedTargetElements, extension TransformationContext context) {
		for (e : annotatedTargetElements) {
			doTransform(new CompilerContext(context, e));			
		}
	}
	
	def doTransform(CompilerContext context) {
		val transformers = context.getTransformers()
		if (transformers != null && !transformers.empty) {
			for (method : context.methods.toList) {
				transformMethod(transformers, method, context)
			}
		}
	}
	
	def transformMethod(Iterable<MethodTransformer> transformers, MutableMethodDeclaration method, CompilerContext context) {
		var destMethod = copyOriginalMethod(context, method, transformers.head)
		
		// this is a reverse list
		val firstTransformer = transformers.last
		var MutableMethodDeclaration currentMethod = destMethod
		
		for (transformer : transformers) {
			if (transformer == firstTransformer) {
				transformer.createForwardingCall(method, method, currentMethod)
				method.docComment = "First in the chain : "+firstTransformer
			} else {
				val duplicateMethod = createDuplicateMethod(context, method, transformer, transformer.name, false)
				duplicateMethod.docComment = "Not last transformer : "+transformer+", first transformer : "+firstTransformer
				transformer.createForwardingCall(method, duplicateMethod, currentMethod)
				currentMethod = duplicateMethod
			}
		}
	}
	
	def generateMethodName(NamedElement element, String suffix) {
		"_"+ element.simpleName + '_' + suffix
	}
	
	def copyOriginalMethod(CompilerContext context, MutableMethodDeclaration method, MethodTransformer firstTransformer) {
		createDuplicateMethod(context, method, firstTransformer, "original", true)
	}
	
	def createDuplicateMethod(CompilerContext context, MutableMethodDeclaration method, MethodTransformer firstTransformer, String suffix, boolean copy) {
		val name = generateMethodName(method, suffix)
		context.classDeclaration.addMethod(name,[
			visibility = Visibility.PRIVATE
			for (param : firstTransformer.transformParameters(method.parameters)) {
				addParameter(param.key, param.value)
			}
			returnType = method.returnType
			if (copy) {
				body = method.body
			}
		])
	}
	
}