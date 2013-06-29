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
	String innerClassName
	String templateClassName

	new(String typeName, String innerClassName, String templateClassName) {
		this._typeName = typeName
		this._innerClassName = innerClassName
		this._templateClassName = templateClassName
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
			val stringTypeArray = (types as String).split("[ ,;]").filter[!it.trim.empty]
			stringTypeArray.fold(map,
				[ tmpRes, stype |
					val simpleName = simplifyName(stype)
					tmpRes.add(
						new ClassInfo(stype, clazz.qualifiedName + '$' + simpleName,
							clazz.qualifiedName + '_' + simpleName))
					tmpRes
				])
		}
		if (types instanceof List<?>) {
			val list = (types as List<?>)
			list.forEach [ value |
				if (value instanceof Type) {
					val t = value as Type
					val simpleName = t.simpleName
					map.add(
						new ClassInfo(t.simpleName, clazz.qualifiedName + '$' + simpleName,
							clazz.qualifiedName + '_' + simpleName))
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
//		if (false) {
//			val X = annot?.getValue("types")
//			if (X instanceof List) {
//				val l = X as List
//				addWarning(clazz,
//					"List :" + l.size + " : " +
//						l.map['(' + it.class.name + ' is ' + it.class.interfaces.map[ii|ii.toString].join + ')'].join)
//			} else {
//				addWarning(clazz, "Hello : " + types + " value:" + X.class)
//			}
//		}

		//addWarning(clazz, "Processing " + clazz.qualifiedName + " to " + types)
		types.forEach [
			val wrappedClass = findTypeGlobally(typeName)?.newTypeReference
			if (wrappedClass == null) {
				addError(clazz, "Unable to locate " + typeName)
				return
			}
			val templateClass = findClass(templateClassName)
			if (templateClass != null) {
				addWarning(templateClass, "Class used for generating " + innerClassName)
			}
			val innerClass = findClass(innerClassName)
			if (innerClass == null) {
				addError(clazz, "Unable to locate innterclass:" + innerClassName)
				return
			}
			innerClass.setExtendedClass(clazzRef)
			innerClass.abstract = false
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
			clazz.declaredMethods.forEach [ absMethod |
				val origMethod = templateClass?.findMethod(absMethod.simpleName, absMethod.parameters.map[it.type])
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
								origMethod.parameters.forEach [ newMethod.addParameter(it.simpleName, it.type)]
								newMethod.body = origMethod.body
								origMethod.remove
							}
						])
				}
			]
		]
	}

	def generateParameterList(int len) {
		if (len > 0) {
			(1 ..< len).fold("_0", [str, i|str + ' ,_' + i])
		} else {
			''
		}

	}

}
