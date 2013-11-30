package com.github.ixlibs.macro.elastix

import java.io.PrintWriter
import java.io.StringWriter
import java.lang.annotation.ElementType
import java.lang.annotation.Target
import java.util.HashSet
import java.util.List
import java.util.Set
import org.eclipse.xtend.lib.macro.Active
import org.eclipse.xtend.lib.macro.RegisterGlobalsContext
import org.eclipse.xtend.lib.macro.RegisterGlobalsParticipant
import org.eclipse.xtend.lib.macro.TransformationContext
import org.eclipse.xtend.lib.macro.TransformationParticipant
import org.eclipse.xtend.lib.macro.declaration.ClassDeclaration
import org.eclipse.xtend.lib.macro.declaration.MutableClassDeclaration
import org.eclipse.xtend.lib.macro.declaration.MutableFieldDeclaration
import org.eclipse.xtend.lib.macro.declaration.TypeReference
import org.eclipse.xtend.lib.macro.declaration.Visibility

@Target(ElementType::TYPE)
@Active(typeof(ElasticStorableProcessor))
annotation ElasticStorable {
	String type = "DEFAULT"
}

@Target(ElementType::FIELD)
annotation Store {
	String fieldName
}

@Target(ElementType::FIELD)
annotation Id {
}

// java 7 has java.beans.Transient
@Target(ElementType::FIELD)
annotation Transient {
}

class ElasticStorableProcessor implements RegisterGlobalsParticipant<ClassDeclaration>, TransformationParticipant<MutableClassDeclaration> {
	val Set<String> beingProcessed = new HashSet()

	override doRegisterGlobals(List<? extends ClassDeclaration> annotatedClasses, RegisterGlobalsContext context) {
		beingProcessed.clear
		for (annotatedClass : annotatedClasses) {
			beingProcessed.add(annotatedClass.qualifiedName)
		}

	}

	override doTransform(List<? extends MutableClassDeclaration> annotatedTargetElements,
		extension TransformationContext context) {
		val c = new CompilerContext(context, beingProcessed)
		if (c.xcontentBuilderType != null) {
			for (annotatedClass : annotatedTargetElements) {
				val idField = locateIdField(annotatedClass, c)
				val typeName = findElasticTypeName(annotatedClass, c)
				c.putClassInfo(annotatedClass, typeName, idField)
			}

			for (annotatedClass : annotatedTargetElements) {
				doTransform(annotatedClass, c)
			}
		} else {
			for (annotatedClass : annotatedTargetElements) {
				context.addError(annotatedClass, "ElasticSearch is not in the classpath!")
			}
		}
	}

	def locateIdField(MutableClassDeclaration annotatedClass, extension CompilerContext context) {
		annotatedClass.declaredFields.findFirst[it.findAnnotation(idAnnotationType) != null]?.simpleName
	}

	def findElasticTypeName(MutableClassDeclaration annotatedClass, extension CompilerContext context) {
		val annot = annotatedClass.findAnnotation(elasticStorableType)?.getValue("type")
		if (annot === null || annot == "DEFAULT") {
			annotatedClass.simpleName.toLowerCase
		} else {
			annot.toString
		}
	}

	def doTransform(MutableClassDeclaration annotatedClass, extension CompilerContext context) {
		val idField = getIdField(annotatedClass)
		annotatedClass.addMethod("serialize",
			[
				addParameter("builder", xcontentBuilderType.newTypeReference)
				exceptions = #{ioExceptionReference}
				body = [
					'''
						«FOR field : annotatedClass.declaredFields»
							«serializeField(field, context)»						
						«ENDFOR»
					'''
				]
			])
		annotatedClass.addMethod("serialize",
			[
				addParameter("builder", indexRequestBuilderType.newTypeReference)
				exceptions = #{ioExceptionReference}
				body = [
					'''
						«IF (idField != null)»
							builder.setId(this.«idField»);
						«ENDIF»
						builder.setType(ElasticType);
						XContentBuilder xcontent = org.elasticsearch.common.xcontent.XContentFactory.jsonBuilder();
						xcontent.startObject();
						serialize(xcontent);
						xcontent.endObject();
						builder.setSource(xcontent);
					'''
				]
			])
		annotatedClass.addMethod("deserialize",
			[
				addParameter("searchHit", searchHitType.newTypeReference)
				returnType = annotatedClass.newTypeReference
				visibility = Visibility::PUBLIC
				body = [
					'''
					«IF (idField != null)»
						this.«idField» = searchHit.id();
					«ENDIF»
					deserializeImpl("", searchHit);
					return this;'''
				]
			])
		annotatedClass.addMethod("deserializeImpl",
			[
				addParameter("prefix", stringTypeReference)
				addParameter("searchHit", searchHitType.newTypeReference)
				visibility = Visibility::PROTECTED
				body = [
					'''
					java.util.Map<String, Object> source = searchHit.sourceAsMap();
					«FOR field : annotatedClass.declaredFields»
					«deserializeField(field, context)»
					«ENDFOR»'''
				]
			])
		annotatedClass.addMethod("apply",
			[
				addParameter("searchHit", searchHitType.newTypeReference)
				returnType = annotatedClass.newTypeReference
				visibility = Visibility::PUBLIC
				static = true
				body = [
					'''
						«annotatedClass.simpleName» obj = new «annotatedClass.simpleName»();
						return obj.deserialize(searchHit);
					'''
				]
			])
		annotatedClass.implementedInterfaces = annotatedClass.implementedInterfaces +
			#{elasticSearchObjectModelReference}

		annotatedClass.addField("BUILDER",
			[
				type = createMapperFunction(annotatedClass.newTypeReference)
				static = true
				final = true
				visibility = Visibility::PUBLIC
				initializer = [
					val nm = annotatedClass.simpleName
					'''
						new Function1<SearchHit,«nm»>() {
							public «nm» apply(final SearchHit hit) {
								«nm» obj = new «nm»();
								obj.deserialize(hit);
								return obj;
							}
						}
					'''
				]
			])
		annotatedClass.addField("ElasticType",
			[
				type = stringTypeReference
				static = true
				final = true
				visibility = Visibility::PUBLIC
				initializer = [
					'"' + getTypeName(annotatedClass) + '"'
				]
			])
	}

	private def isStoredField(MutableFieldDeclaration field, CompilerContext context) {
		(!field.static) && (field.findAnnotation(context.transientType) == null) &&
			(field.findAnnotation(context.idAnnotationType) == null)
	}

	private def String serializeField(MutableFieldDeclaration field, CompilerContext context) {
		try {
			if (isStoredField(field, context)) {
				val key = context.annotationValue(field, context.storeFieldType, "fieldName")
				serializeField(field.type, field.simpleName, context, key as String)
			} else {
				""
			}
		} catch (Exception e) {
			handleException(e, field, context)
		}
	}

	private def String serializeField(TypeReference ft, String name, extension CompilerContext context, String key) {
		val keyName = normalizeKeyName(name)
		if (simpleType(ft)) {
			'builder.field("' + keyName + '",' + name + ');'
		} else if (dateTypeReference.isAssignableFrom(ft)) {
			'''
				if («name» != null) {
				  builder.field("«keyName»",«name».getTime());
				} else {
				  builder.field("«keyName»").nullValue();
				}
			'''
		} else if (ft.array && simpleType(ft.arrayComponentType)) {
			'''
				if («name»!=null) {
				  builder.array("«keyName»",«name»);
				}
			'''
		} else if (iterableTypeReference.isAssignableFrom(ft)) {
			val colType = getCollectionType(ft, context)
			if (simpleType(colType)) {
				'''
					if («name»!=null) {
					  builder.startArray("«keyName»");
					  for («colType.simpleName» obj : «name») {
						builder.value(obj);
					 }
					 builder.endArray();
					}
				'''
			} else {
				'''
					if («name»!=null) {
					  builder.startArray("«keyName»");
					  for («colType.simpleName» obj : «name») {
					  	«IF (key == null)»
						«serializeField(colType, "obj", context, null)»
						«ELSE»
						builder.value(obj.«key»);
						«ENDIF»
					  }
					  builder.endArray();
					}
				'''
			}
		} else if (hasSerializer(ft)) {
			'''
				if («name»!=null) {
				  builder.startObject("«ft.simpleName.toLowerCase»");
				  «name».serialize(builder);
				  builder.endObject();
				}
			'''

		} else {
			"// field type is " + ft + ", " + ft.type
		}
	}

	private def getCollectionType(TypeReference ft, CompilerContext context) {
		val typeArgs = ft.actualTypeArguments
		if (typeArgs.size >= 1) {
			typeArgs.get(0)
		} else {
			context.object
		}
	}

	private def String deserializeField(MutableFieldDeclaration field, CompilerContext context) {
		try {
			if (isStoredField(field, context)) {
				val key = context.annotationValue(field, context.storeFieldType, "fieldName")
				deserializeField(field.type, field.simpleName, context, key as String)
			} else {
				""
			}
		} catch (Exception e) {
			handleException(e, field, context)
		}
	}

	private def handleException(Exception e, MutableFieldDeclaration field, CompilerContext context) {
		val s = new StringWriter
		e.printStackTrace(new PrintWriter(s))
		context.addError(field,
			"Error converting field : " + field + ", msg:" + e.message + ", \nstackTrace:" + s.toString)
		"// Error converting field : " + field + ", msg:" + e.message + " \n /* " + s.toString + " \n */"
	}

	private def normalizeKeyName(String name) {
		name.replaceAll("^_*", "")
	}

	private def String deserializeField(TypeReference ft, String name, extension CompilerContext context, String key) {
		val keyName = normalizeKeyName(name)
		if (simpleType(ft)) {
			'this.' + name + ' = ' + getConvertMethodName(ft) + '( source.get(prefix + "' + keyName + '") );'
		} else if (dateTypeReference.isAssignableFrom(ft)) {
			'this.' + name + ' = ' + getConvertMethodName(ft) + '( source.get(prefix + "' + keyName + '") );'
		} else if (ft.array && simpleType(ft.arrayComponentType)) {
			'''
				{ 
					java.util.List<Object> __values = searchHit.field(prefix + "«keyName»").values();
					if (__values != null) {
					  this.«name» = __values.toArray(new «ft.arrayComponentType»[__values.size()]);
					}
				} 
			'''
		} else if (iterableTypeReference.isAssignableFrom(ft)) {
			val mappedType = fixTypeMapping.get(ft.type.qualifiedName)
			val actualType = if (mappedType != null) {
					mappedType
				} else {
					ft.type.qualifiedName
				}
			val colType = getCollectionType(ft, context)
			if (simpleType(colType)) {
				'''
					{
					  this.«name» = new «actualType»();
					  java.util.List<Object> __values = (java.util.List<Object>) source.get(prefix + "«keyName»");
					  if (__values != null) {
					    for (Object value : __values) {
					      if (value instanceof «colType.type.qualifiedName») {
					        this.«name».add((«colType.type.qualifiedName»)value);
					      }
					    }
					  }
					}
				'''
			} else {
				" /// unable to handle " + ft
			}
		} else {
			"// unknown field " + ft
		}
	}

	val fixTypeMapping = #{"java.util.List" -> "java.util.ArrayList", "java.util.Set" -> "java.util.HashSet", "java.util.Collection" ->
		"java.util.HashSet"}

	val packageName = typeof(Util).package.name
	
	def getConvertMethodName(TypeReference type) {
		packageName + ".Util.to" + type.simpleName
	}

}
