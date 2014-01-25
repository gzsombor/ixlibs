package com.github.ixlibs.macro.aopx

import java.util.Collections
import org.eclipse.xtend.lib.macro.declaration.MutableClassDeclaration
import org.eclipse.xtend.lib.macro.declaration.MutableMethodDeclaration
import org.eclipse.xtend.lib.macro.declaration.MutableParameterDeclaration
import org.eclipse.xtend.lib.macro.declaration.Type

class JPATransactionTransformer extends NopMethodTransformer {

	var String fieldName
	var Type entityManagerType 

	override name() {
		"jpa"
	}

	override startClassTransformation(MutableClassDeclaration cls) {
		fieldName = cls.declaredFields.findFirst[it.type.name == "javax.persistence.EntityManagerFactory"]?.simpleName
		entityManagerType = findTypeGlobally("javax.persistence.EntityManager")
	}
	
	override transformParameters(Iterable<? extends MutableParameterDeclaration> parameters) {
		Collections.singletonList("manager" -> entityManagerType.newTypeReference) + super.transformParameters(parameters)
	}

	override createForwardingCall(MutableMethodDeclaration originalMethod,MutableMethodDeclaration method, MutableMethodDeclaration destMethod) {
		if (fieldName != null && entityManagerType != null) {
			method.body = ['''
				javax.persistence.EntityManager manager = «fieldName».createEntityManager();
				manager.getTransaction().begin();
				try {
					«methodCallAndReturn(destMethod, destMethod.simpleName)»
				} catch (RuntimeException e) {
					manager.getTransaction().rollback();
					throw e;
				} finally {
					if (manager.getTransaction().isActive()) {
						manager.getTransaction().commit();
					}
				}
			''']
		} else {
			super.createForwardingCall(originalMethod, method, destMethod)
		}
		
	}

}
