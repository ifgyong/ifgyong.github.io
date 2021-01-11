{%- if page.prev or page.next %}
 <nav class="pagination">
   {{
     paginator({
       prev_text: '<i class="fa fa-angle-left" aria-label="'+__('accessibility.prev_page')+'">上一页</i>',
       next_text: '<i class="fa fa-angle-right" aria-label="'+__('accessibility.next_page')+'">下一页</i>',
       mid_size: 1,
       escape: false
     })
   }}
 </nav>
{%- endif %}