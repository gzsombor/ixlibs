package com.github.ixlibs.macro.union

import java.io.PrintWriter
import java.io.StringWriter
import java.lang.annotation.ElementType
import java.lang.annotation.Target
import java.util.ArrayList
import java.util.HashMap
import java.util.List
import org.eclipse.xtend.lib.macro.AbstractClassProcessor
import org.eclipse.xtend.lib.macro.Active
import org.eclipse.xtend.lib.macro.RegisterGlobalsContext
import org.eclipse.xtend.lib.macro.TransformationContext
import org.eclipse.xtend.lib.macro.declaration.AnnotationReference
import org.eclipse.xtend.lib.macro.declaration.ClassDeclaration
import org.eclipse.xtend.lib.macro.declaration.MutableClassDeclaration
import org.eclipse.xtend.lib.macro.declaration.MutableMethodDeclaration
import org.eclipse.xtend.lib.macro.declaration.Type
import org.eclipse.xtend.lib.macro.declaration.Visibility

@Target(ElementType::TYPE)
@Active(typeof(UnionProcessor))
annotation Union { // This is a string, until arrays could properly used
	String types

}

@Data
package class ClassInfo {
	String typeName
	String simpleTypeName
	String innerClassName
	String templateClassName

	new(String typeName, String simpleName, String qualifiedName) {
		this._typeName = typeName
		this._simpleTypeName = simpleName
		this._innerClassName = qualifiedName + '$Wrapper' + simpleName
		this._templateClassName = qualifiedName + '_' + simpleName
	}

	def getInnerClassSimpleName() {
		innerClassName
		// "Wrapper" + simpleTypeName
	}
}

class UnionProcessor extends AbstractClassProcessor {

	val stuff = new HashMap<String, String>()

	override doRegisterGlobals(ClassDeclaration clazz, RegisterGlobalsContext context) {
		val annot = clazz.getAnnotations.findFirst[it.annotationTypeDeclaration.qualifiedName == typeof(Union).name]
		val types = getInnerClasses(clazz, annot)
		stuff.put(clazz.qualifiedName, "Info : " + annot + " - " + types.toString/*types.entrySet.fold("", [ str,x | str + ', '+ x])*/)
		types.forEach [
			context.registerClass(innerClassName)
		]
	}

	def String simplifyName(String name) {
		if (name != null && name.lastIndexOf('.') > 0) {
			name.substring(name.lastIndexOf('.') + 1)
		} else {
			name
		}
	}

	def getInnerClasses(ClassDeclaration clazz, AnnotationReference annot) {
		val map = new ArrayList<ClassInfo>()
		val types = annot?.getValue("types")
		if (types instanceof String) {
			val stringTypeArray = types.split("[ ,;]").filter[!it.trim.empty]
			stringTypeArray.fold(map,
				[ tmpRes, stype |
					val simpleName = simplifyName(stype)
					tmpRes.add(new ClassInfo(stype, simpleName, clazz.qualifiedName))
					tmpRes
				])
		}
		if (types instanceof List<?>) {
			types.forEach [ value |
				if (value instanceof Type) {
					map.add(new ClassInfo(value.qualifiedName, value.simpleName, clazz.qualifiedName))
				}
			]
		}
		map
	}

	override doTransform(MutableClassDeclaration clazz, TransformationContext context) {
		try {
			doTransformImpl(clazz, context)
		} catch (Exception e) {
			val s = new StringWriter
			e.printStackTrace(new PrintWriter(s))
			context.addError(clazz, "Error : " + e.message + " \n\t" + s.toString)
		}
	}

	def doTransformImpl(MutableClassDeclaration clazz, extension TransformationContext context) {
		val clazzRef = newTypeReference(clazz)

		val annot = clazz.findAnnotation(findTypeGlobally(typeof(Union)))
		val types = getInnerClasses(clazz, annot)

		types.forEach [ ci |
			val globalType = findTypeGlobally(ci.typeName)
			if (globalType == null) {
				addError(clazz, "Unable to locate " + ci.typeName)
				return
			}
			val wrappedClass = globalType.newTypeReference
			val templateClass = findClass(ci.templateClassName)
			if (templateClass != null) {
				addWarning(templateClass, "Class used for generating " + ci.innerClassName)
			}
			val innerClass = findClass(ci.innerClassName)
			if (innerClass == null) {
				addError(clazz, "Unable to locate innterclass:" + ci.innerClassName)
				return
			}
			innerClass.setExtendedClass(clazzRef)
			innerClass.abstract = false
			innerClass.final = true
			innerClass.addField("internal",
				[
					type = wrappedClass
					visibility = Visibility::PRIVATE
					final = true
				])
			innerClass.addConstructor [
				addParameter("toBeWrapped", wrappedClass)
				body = [''' this.internal = toBeWrapped; ''']
			]
			innerClass.addMethod("is" + globalType.simpleName,
				[
					returnType = primitiveBoolean
					body = ["return true;"]
				])
			innerClass.addMethod("as" + globalType.simpleName,
				[
					returnType = wrappedClass
					body = ["return this.internal;"]
				])
			// copy/implement/overwrite the parent method to the child
			clazz.declaredMethods.forEach [ absMethod |
				convertMethod(absMethod, innerClass, templateClass, context)
			]
			// add methods for the main class
			clazz.addMethod("from",
				[
					static = true
					returnType = clazzRef
					addParameter("original", wrappedClass)
					body = [''' return new «ci.innerClassSimpleName»(original);''']
				])
			clazz.addMethod("is" + globalType.simpleName,
				[
					returnType = primitiveBoolean
					body = ["return false;"]
				])
			clazz.addMethod("as" + globalType.simpleName,
				[
					returnType = wrappedClass
					body = [
						'''throw new ClassCastException("Unable to cast «this.class.name» to «globalType.simpleName»");''']
				])
		]

	}

	def private convertMethod(MutableMethodDeclaration absMethod, MutableClassDeclaration innerClass,
		MutableClassDeclaration templateClass, extension TransformationContext context) {
		val origMethod = templateClass?.findDeclaredMethod(absMethod.simpleName, absMethod.parameters.map[it.type])
		if (absMethod.abstract || origMethod != null) {
			innerClass.addMethod(absMethod.simpleName,
				[ newMethod |
					newMethod.returnType = absMethod.returnType
					if (origMethod == null) {
						absMethod.parameters.fold(0,
							[ i, origParameter |
								newMethod.addParameter("_" + i, origParameter.type)
								i + 1
							])
						addWarning(innerClass,
							"adding " + absMethod.simpleName + " to " + innerClass.qualifiedName)
						val call = 'internal.' + absMethod.simpleName + '(' +
							generateParameterList(absMethod.parameters.size) + ');'
						if (newMethod.returnType.void) {
							newMethod.body = [call]
						} else {
							newMethod.body = ["return " + call]
						}
					} else {
						addWarning(innerClass,
							"copying " + absMethod.simpleName + " to " + innerClass.qualifiedName + " from " +
								templateClass.qualifiedName)
						origMethod.parameters.forEach[newMethod.addParameter(it.simpleName, it.type)]
						newMethod.body = origMethod.body
						origMethod.remove
					}
				])
		}
	}

	def generateParameterList(int len) {
		if (len > 0) {
			(1 ..< len).fold("_0", [str, i|str + ' ,_' + i])
		} else {
			''
		}

	}

}
