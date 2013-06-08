package com.github.ixlibs.macro.property

import org.eclipse.xtend.lib.macro.AbstractFieldProcessor
import org.eclipse.xtend.lib.macro.TransformationContext
import org.eclipse.xtend.lib.macro.declaration.MutableFieldDeclaration
import org.eclipse.xtend.lib.macro.declaration.Visibility

class PropertyProcessor extends AbstractFieldProcessor {
	
	override doTransform(MutableFieldDeclaration annotatedField, extension TransformationContext context) {
		val annot = annotatedField.findAnnotation(findTypeGlobally(typeof(Property)))
		val read = Boolean::TRUE == annot.getValue("read")
		val readFunction = annot.getValue("readFunction") as String
		val write = Boolean::TRUE == annot.getValue("write") 
		val writeFunction = annot.getValue("writeFunction") as String
		val builder = Boolean::TRUE == annot.getValue("builder")
		
		println("field for "+ annotatedField.simpleName + " is " + read + " "+ write)
		
		val newName = Character::toUpperCase(annotatedField.simpleName.charAt(0)) + annotatedField.simpleName.substring(1)
		val newFieldName = '_' + annotatedField.simpleName
		
		annotatedField.simpleName = newFieldName
		
		val mainClass = annotatedField.declaringType
		if (read) {
			val prefix = if (annotatedField.type.type == findTypeGlobally(typeof(boolean)) || 
				annotatedField.type.type == findTypeGlobally(typeof(Boolean))) {
				"is"
			}  else {
				"get"
			}
			mainClass.addMethod(prefix + newName, [
				visibility = Visibility::PUBLIC
				returnType = annotatedField.type
				body = [
					buildReadMethod(newFieldName, readFunction)
				]
			])
		}
		if (write || builder) {
			mainClass.addMethod("set" + newName, [
				visibility = Visibility::PUBLIC
				addParameter("value", annotatedField.type)
				if (builder) {
					returnType = newTypeReference(mainClass)
				}	
				body = [
					buildWriteMethod(newFieldName, writeFunction, builder)
				]
			])
			
		}
		
	}
	
	
	def buildReadMethod(String newFieldName, String readFunction) {
		if (readFunction.trim.length == 0) {
			return "return this." + newFieldName + ";"
		} else {
			return "return " + readFunction.replaceAll("\\$", newFieldName)+";"
		}
	}

	def buildWriteMethod(String newFieldName, String writeFunction, boolean builder) {
		val statement = if (writeFunction.trim.length == 0) {
			"this." + newFieldName + " = value;"
		} else {
			"this. " + newFieldName + " = " + writeFunction.replaceAll("\\$", "value")+";"
		}
		if (builder) {
			statement + "\nreturn this;"
		} else {
			statement
		}
	}

	
}
