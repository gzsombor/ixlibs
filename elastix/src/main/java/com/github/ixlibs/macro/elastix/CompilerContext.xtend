package com.github.ixlibs.macro.elastix

import java.io.IOException
import java.util.Date
import java.util.HashMap
import java.util.HashSet
import java.util.Map
import java.util.Set
import org.eclipse.xtend.lib.macro.TransformationContext
import org.eclipse.xtend.lib.macro.declaration.ClassDeclaration
import org.eclipse.xtend.lib.macro.declaration.Element
import org.eclipse.xtend.lib.macro.declaration.MutableAnnotationTarget
import org.eclipse.xtend.lib.macro.declaration.Type
import org.eclipse.xtend.lib.macro.declaration.TypeReference
import org.eclipse.xtext.xbase.lib.Functions

@Data
class ClassInfo {
	String typeName
	String idField
}

class CompilerContext {
	val extension TransformationContext transformation;
	protected val Type xcontentBuilderType
	protected val Type indexRequestBuilderType

	protected val Type searchHitType

	protected val Type transientType

	protected val Type idAnnotationType

	protected val TypeReference dateTypeReference

	protected val Type elasticStorableType

	protected val Type storeFieldType

	protected val TypeReference iterableTypeReference

	protected val TypeReference stringTypeReference

	val Set<String> elasticType = new HashSet();
	val Set<String> notElasticType = new HashSet();
	val Map<String, ClassInfo> classInfoMap = new HashMap()

	new(TransformationContext context, Set<String> types) {
		this.transformation = context
		this.elasticType.addAll(types)
		xcontentBuilderType = findTypeGlobally("org.elasticsearch.common.xcontent.XContentBuilder")
		indexRequestBuilderType = findTypeGlobally("org.elasticsearch.action.index.IndexRequestBuilder")
		searchHitType = findTypeGlobally("org.elasticsearch.search.SearchHit")
		transientType = findTypeGlobally(typeof(Transient))
		dateTypeReference = newTypeReference(typeof(Date))
		elasticStorableType = findTypeGlobally(typeof(ElasticStorable))
		iterableTypeReference = wrapWithWildcard(typeof(Iterable))
		storeFieldType = findTypeGlobally(typeof(Store))
		stringTypeReference = newTypeReference(typeof(String))
		idAnnotationType = findTypeGlobally(typeof(Id))
	}

	def ioExceptionReference() {
		newTypeReference(typeof(IOException))
	}

	def elasticSearchObjectModelReference() {
		newTypeReference(typeof(ElasticSearchObjectModel))
	}

	def createMapperFunction(TypeReference destType) {
		newTypeReference(typeof(Functions$Function1), searchHitType.newTypeReference, destType)
	}

	public def boolean simpleType(TypeReference t) {
		t.primitive || t == string || t.wrapper
	}

	public def boolean hasSerializer(TypeReference ft) {
		val qn = ft.type.qualifiedName
		if (elasticType.contains(qn)) {
			true
		} else {
			if (notElasticType.contains(qn)) {
				false
			} else {
				val md = findTypeGlobally(qn)
				if (md instanceof ClassDeclaration) {
					val cd = md as ClassDeclaration
					if (cd.findAnnotation(elasticStorableType) != null) {
						elasticType.add(qn)
						true
					} else {
						notElasticType.add(qn)
						false
					}
				} else {
					false
				}
			}
		}
	}

	def Object annotationValue(MutableAnnotationTarget target, Type type, String propertyName) {
		val ann = target.findAnnotation(type)
		if (ann != null) {
			ann.getValue(propertyName)
		} else {
			null
		}
	}

	def TypeReference newTypeReference(Type typeDeclaration, TypeReference... typeArguments) {
		transformation.newTypeReference(typeDeclaration, typeArguments)
	}

	def TypeReference wrapWithWildcard(Class<?> cls) {
		newTypeReference(cls, newWildcardTypeReference)
	}

	def void addError(Element element, String message) {
		transformation.addError(element, message)
	}

	def object() {
		transformation.object
	}

	def getIdField(Type typeDeclaration) {
		classInfoMap.get(typeDeclaration.qualifiedName)?.idField
	}

	def getTypeName(Type typeDeclaration) {
		classInfoMap.get(typeDeclaration.qualifiedName)?.typeName
	}

	public def putClassInfo(Type typeDeclaration, String typeName, String idName) {
		classInfoMap.put(typeDeclaration.qualifiedName, new ClassInfo(typeName, idName))
	}

}
