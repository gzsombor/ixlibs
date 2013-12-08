package com.github.ixlibs.macro.aopx

import org.eclipse.xtend.lib.macro.declaration.MutableMethodDeclaration

class LoggingMethodTransformer extends MethodTransformer {

	override name() {
		"logging"
	}

	override createForwardingCall(MutableMethodDeclaration originalMethod, MutableMethodDeclaration currentMethod, MutableMethodDeclaration destMethod) {
		currentMethod.body = [
			if (destMethod.returnType.void) {
				'''
				System.out.println("starting «originalMethod.simpleName»");
				«methodCall(destMethod, destMethod.simpleName)»;
				System.out.println("finishing «originalMethod.simpleName»");
				'''
			} else {
				'''
				System.out.println("starting «originalMethod.simpleName»");
				«destMethod.returnType.simpleName» result = «methodCall(destMethod, destMethod.simpleName)»;
				System.out.println("finishing «originalMethod.simpleName», result is : "+result);
				return result;
				'''
			}
			
		]
	}

}
