package com.github.ixlibs.macro.aopx

import java.lang.annotation.ElementType
import java.lang.annotation.Target
import org.eclipse.xtend.lib.macro.declaration.MutableMethodDeclaration
import org.eclipse.xtend.lib.macro.declaration.ParameterDeclaration
import org.eclipse.xtend.lib.macro.declaration.Type
import org.eclipse.xtend.lib.macro.TransformationContext

@Target(ElementType::PARAMETER)
annotation NotNull {
	
}

class ValidatingMethodTransformer extends MethodTransformer {
	
	var Type notNullType
	
	override name() {
		"validating"
	}
	
	override init(TransformationContext context) {
		super.init(context)
		notNullType = findTypeGlobally(NotNull)
	}
	
	override createForwardingCall(MutableMethodDeclaration originalDeclaration, MutableMethodDeclaration method, MutableMethodDeclaration destMethod) {
		method.body = ['''
			«FOR param : originalDeclaration.parameters»
				«IF isNotNull(param)»
			assert «param.simpleName» != null : "«param.simpleName» is null!";				
				«ENDIF»			
			«ENDFOR»
			«methodCallAndReturn(destMethod, destMethod.simpleName)»
		''']
	}
	
	def isNotNull(ParameterDeclaration parameter) {
		!parameter.type.primitive && parameter.findAnnotation(notNullType) != null
	}
	
}