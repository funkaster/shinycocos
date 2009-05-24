/*
 *   ShinyCocos - ruby bindings for the cocos2d-iphone game framework
 *   Copyright (C) 2009, Rolando Abarca M.
 *
 *   This library is free software; you can redistribute it and/or
 *   modify it under the terms of the GNU Lesser General Public
 *   License as published by the Free Software Foundation; either
 *   version 2.1 of the License.
 *
 *   This library is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *   Lesser General Public License for more details.
 *
 *   You should have received a copy of the GNU Lesser General Public
 *   License along with this library; if not, write to the Free Software
 *   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "SC_common.h"
#import "SC_CocosNode.h"
#import "SC_Layer.h"

#pragma mark MenuItem

// proxy for the MenuItem, it will hold the reference to a ruby object that will
// be called when this object is called by the menu item
@interface MenuItemProxy : NSObject
{
	VALUE rbObject;
	id    menuItem;
}

@property (readwrite, assign) VALUE rbObject;

+ (id)proxy;
- (id)initWithRubyObject:(VALUE)object;
- (void)proxyRuby:(id)sender;
@end

@implementation MenuItemProxy
@synthesize rbObject;
+ (id)proxy {
	return [[[self alloc] initWithRubyObject:Qnil] autorelease];
}

- (id)initWithRubyObject:(VALUE)object {
	if (self = [super init]) {
		if (object != Qnil)
			rbObject = object;
	}
	return self;
}

- (void)proxyRuby:(id)sender {
	if (rb_respond_to(rbObject, id_sc_item_action)) {
		rb_funcall(rbObject, id_sc_item_action, 0, 0);
	}
}
@end

VALUE rb_cMenuItemImage;

/*
 * call-seq:
 *   item = MenuItemImage.new(:normal => "normal_image.png",
 *                            :selected => "selected_image.png",
 *                            :disabled => "disabled_image.png")   #=> MenuItemImage
 *
 * <tt>:normal</tt> and <tt>:selected</tt> are required.
 */
VALUE rb_cMenuItemImage_s_new(VALUE klass, VALUE opts) {
	Check_Type(opts, T_HASH);
	// check options
	VALUE normal_image = rb_hash_aref(opts, ID2SYM(id_sc_normal));
	if (normal_image == Qnil)
		rb_raise(rb_eArgError, "normal image required");
	VALUE selected_image = rb_hash_aref(opts, ID2SYM(id_sc_selected));
	if (selected_image == Qnil)
		rb_raise(rb_eArgError, "selected image required");
	VALUE disabled_image = rb_hash_aref(opts, ID2SYM(id_sc_disabled));
	NSString *normalImage = [NSString stringWithCString:StringValueCStr(normal_image) encoding:NSUTF8StringEncoding];
	NSString *selectedImage = [NSString stringWithCString:StringValueCStr(selected_image) encoding:NSUTF8StringEncoding];
	NSString *disabledImage = (disabled_image != Qnil) ? [NSString stringWithCString:StringValueCStr(disabled_image) encoding:NSUTF8StringEncoding] : nil;
	// create proxy
	MenuItemProxy *mp = [[MenuItemProxy alloc] initWithRubyObject:Qnil];
	MenuItemImage *mi = [[MenuItemImage alloc] initFromNormalImage:normalImage
													 selectedImage:selectedImage
													 disabledImage:disabledImage
															target:mp
														  selector:@selector(proxyRuby:)];
	VALUE ret = sc_init(klass, nil, mi, 0, 0, YES);
	mp.rbObject = ret;
	
	return ret;
}

void init_rb_cMenuItemImage() {
	rb_cMenuItemImage = rb_define_class_under(rb_mCocos2D, "MenuItemImage", rb_cCocosNode);
	rb_define_singleton_method(rb_cMenuItemImage, "new", rb_cMenuItemImage_s_new, 1);
}

#pragma mark Menu

VALUE rb_cMenu;

typedef union {
	va_list varargs;
	void *packedArray;
} fakeArray;

/*
 * call-seq:
 *   menu = Menu.new(item1, item2, item3)   #=> Menu
 *
 *   menu = Menu.new do |items|   #=> Menu
 *     items << MyMenuItem.new
 *     items << OtherMenuItem.new
 *     ...
 *   end
 *
 * There are two ways of creating the menu: passing the items as arguments, or
 * using the block initializer. In the latter version, the argument of the block
 * is an empty array.
 */
VALUE rb_cMenu_s_new(VALUE klass, VALUE args) {
	if (RARRAY_LEN(args) < 1 && rb_block_given_p()) {
		rb_yield(args);
	} else if (RARRAY_LEN(args) < 1) {
		rb_raise(rb_eArgError, "Invalid number of items or no block given");
	}
	cocos_holder *ptr;
	int i;
	// get first element
	Data_Get_Struct(RARRAY_PTR(args)[0], cocos_holder, ptr);
	id first = CC_NODE(ptr);
	// create a va_list for the rest of the elements
	fakeArray fa;
	fa.packedArray = alloca(sizeof(id) * RARRAY_LEN(args));
	void *p = fa.packedArray;
	for (i=1; i < RARRAY_LEN(args); i++) {
		Data_Get_Struct(RARRAY_PTR(args)[i], cocos_holder, ptr);
		*(id *)p = CC_NODE(ptr);
		p += sizeof(id);
	}
	// terminator of the va_list
	*(id *)p = nil;
	
	Menu *menu = [[Menu alloc] initWithItems:first vaList:fa.varargs];
	VALUE ret = sc_init(klass, nil, menu, 0, 0, YES);
	sc_add_tracking(sc_object_hash, menu, ret);
	
	return ret;
}


/*
 * call-seq:
 *   menu.align(:horizontally, padding)   #=> menu
 *
 * Align the items horizontally or vertically, with or without padding.
 *
 * Valid options:
 *
 * * <tt>:horizontally</tt>
 * * <tt>:vertically</tt>
 */
VALUE rb_cMenu_align(int argc, VALUE *argv, VALUE obj) {
	if (argc < 1 || argc > 2) {
		rb_raise(rb_eArgError, "Invalid arguments");
	}
	Check_Type(argv[0], T_SYMBOL);
	cocos_holder *ptr;
	Data_Get_Struct(obj, cocos_holder, ptr);
	if (argv[0] == ID2SYM(id_sc_horizontally)) {
		if (argc == 2) {
			Check_Type(argv[1], T_FLOAT);
			[CC_MENU(ptr) alignItemsHorizontallyWithPadding:NUM2DBL(argv[1])];
		} else {
			[CC_MENU(ptr) alignItemsHorizontally];
		}
	} else if (argv[0] == ID2SYM(id_sc_vertically)) {
		if (argc == 2) {
			[CC_MENU(ptr) alignItemsVerticallyWithPadding:NUM2DBL(argv[1])];
		} else {
			[CC_MENU(ptr) alignItemsVertically];
		}
	}
	return obj;
}

void init_rb_cMenu() {
	rb_cMenu = rb_define_class_under(rb_mCocos2D, "Menu", rb_cLayer);
	rb_define_singleton_method(rb_cMenu, "new", rb_cMenu_s_new, -2);
	rb_define_method(rb_cMenu, "align", rb_cMenu_align, -1);
}